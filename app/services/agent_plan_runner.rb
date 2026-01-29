class AgentPlanRunner
  MAX_SCHEMA_ATTEMPTS = 2
  FALLBACK_MODEL_NAME = "heuristic"

  def initialize(lead:, mode:)
    @lead = lead
    @mode = mode
  end

  def call
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    agent_run = AgentRun.create!(
      lead: @lead,
      status: "started",
      model: AgentPlanGeneration::OpenAiPlanGenerator.model_name,
      input_context: build_input_context
    )
    @agent_run = agent_run

    agent_run.update!(status: "validating")

    plan, validation_errors = generate_valid_plan
    agent_run.update!(model: @model_used || agent_run.model)
    if validation_errors.any?
      agent_run.update!(
        status: "failed",
        validation_errors: validation_errors,
        duration_ms: duration_ms_since(start_time)
      )
      log_action(agent_run, "validate_plan", "error", { errors: validation_errors }, validation_errors.join("; "))
      @lead.update!(status: "failed")
      return { agent_run: agent_run, errors: validation_errors }
    end

    plan, adjustments = apply_guardrails(plan)
    agent_run.update!(
      status: "validated",
      output_plan: plan,
      validation_errors: [],
      duration_ms: duration_ms_since(start_time)
    )
    log_action(agent_run, "validate_plan", "ok", { plan: plan, adjustments: adjustments })

    if @mode == "plan_only"
      log_action(agent_run, "plan_only", "ok", { plan: plan })
      @lead.update!(status: "planned")
      return { agent_run: agent_run, plan: plan, mode: "plan_only" }
    end

    if active_assignment_exists?
      message = "Lead already has an active assignment."
      log_action(agent_run, "assignment_locked", "error", { message: message }, message)
      agent_run.update!(
        status: "failed",
        validation_errors: [message],
        duration_ms: duration_ms_since(start_time)
      )
      @lead.update!(status: "failed")
      return { agent_run: agent_run, errors: [message], mode: @mode }
    end

    agent_run.update!(status: "executing")
    execution = PlanExecutor.new(lead: @lead, agent_run: agent_run, plan: plan).call

    if execution[:ok]
      agent_run.update!(status: "succeeded", duration_ms: duration_ms_since(start_time))
      @lead.update!(status: "executed")
    else
      agent_run.update!(status: "failed", duration_ms: duration_ms_since(start_time))
      @lead.update!(status: "failed")
    end

    execution.merge(agent_run: agent_run, plan: plan, mode: @mode)
  end

  private

  def generate_valid_plan
    input_context = build_input_context
    input_payload = build_openai_payload(input_context)
    schema_reference = plan_schema_reference

    attempt = openai_plan_result(input_payload: input_payload, schema_reference: schema_reference)
    if attempt[:error]
      log_action(
        @agent_run,
        "openai_generate_plan",
        "error",
        { error: attempt[:error], duration_ms: attempt[:duration_ms], model: attempt[:model] },
        attempt[:error]
      )
      return fallback_plan_with_validation
    end

    log_action(
      @agent_run,
      "openai_generate_plan",
      "ok",
      { duration_ms: attempt[:duration_ms], model: attempt[:model] }
    )

    plan = normalize_plan(attempt[:plan])
    validation_errors = validate_plan(plan)
    return [plan, []] if validation_errors.empty?

    repair = repair_plan(
      invalid_json: attempt[:raw_json],
      validation_errors: validation_errors,
      input_payload: input_payload,
      schema_reference: schema_reference
    )

    if repair[:error]
      log_action(
        @agent_run,
        "openai_repair_plan",
        "error",
        { error: repair[:error], duration_ms: repair[:duration_ms], model: repair[:model] },
        repair[:error]
      )
      return fallback_plan_with_validation
    end

    log_action(
      @agent_run,
      "openai_repair_plan",
      "ok",
      { duration_ms: repair[:duration_ms], model: repair[:model] }
    )

    plan = normalize_plan(repair[:plan])
    validation_errors = validate_plan(plan)
    return [plan, []] if validation_errors.empty?

    fallback_plan_with_validation
  end

  def generate_plan(input_payload:, schema_reference:)
    result = openai_plan_result(input_payload: input_payload, schema_reference: schema_reference)
    return {} if result[:error]

    normalize_plan(result[:plan])
  end

  def openai_plan_result(input_payload:, schema_reference:)
    result = AgentPlanGeneration::OpenAiPlanGenerator.call(
      input_payload: input_payload,
      schema_reference: schema_reference
    )
    @model_used = result[:model] if result[:model]
    result
  end

  def repair_plan(invalid_json:, validation_errors:, input_payload:, schema_reference:)
    result = AgentPlanGeneration::OpenAiJsonRepair.call(
      invalid_json: invalid_json,
      validation_errors: validation_errors,
      input_payload: input_payload,
      schema_reference: schema_reference
    )
    @model_used = result[:model] if result[:model]
    result
  end

  def fallback_plan_with_validation
    @model_used = FALLBACK_MODEL_NAME
    plan = deterministic_plan
    validation_errors = validate_plan(plan)
    [plan, validation_errors]
  end

  def deterministic_plan
    service_code = infer_service_code
    pricing_rule = PricingRule.find_by(service_code: service_code)
    subcontractor = select_subcontractor(service_code)
    schedule = build_schedule(subcontractor)

    base_price = pricing_rule&.base_price_cents || 50000
    line_item = {
      description: "Service: #{service_code.to_s.tr('_', ' ')}",
      quantity: 1,
      unit_price_cents: base_price,
      total_cents: base_price
    }

    {
      service_code: service_code,
      urgency_level: infer_urgency_level,
      quote: {
        line_items: [line_item],
        total_cents: base_price
      },
      schedule: schedule,
      subcontractor_id: subcontractor&.id,
      customer_message: customer_message(schedule),
      confidence: confidence_score(service_code, subcontractor),
      assumptions: ["Single service visit", "No access restrictions noted"]
    }
  end

  def normalize_plan(plan)
    return {} unless plan.is_a?(Hash)
    plan.deep_symbolize_keys
  end

  def validate_plan(plan)
    JSON::Validator.fully_validate(plan_schema, plan.deep_stringify_keys)
  end

  def apply_guardrails(plan)
    adjustments = []
    pricing_rule = PricingRule.find_by(service_code: plan[:service_code])

    if pricing_rule
      total = plan.dig(:quote, :total_cents).to_i
      bounded_total = [[total, pricing_rule.min_price_cents].max, pricing_rule.max_price_cents].min

      if bounded_total != total
        adjustments << "Adjusted price to #{bounded_total} cents to meet bounds."
        plan[:quote][:total_cents] = bounded_total
        plan[:quote][:line_items].each do |item|
          item[:unit_price_cents] = bounded_total
          item[:total_cents] = bounded_total
        end
      end
    end

    subcontractor = Subcontractor.find_by(id: plan[:subcontractor_id])
    unless subcontractor&.service_codes&.include?(plan[:service_code])
      subcontractor = select_subcontractor(plan[:service_code])
      adjustments << "Reassigned subcontractor for service coverage."
      plan[:subcontractor_id] = subcontractor&.id
    end

    adjustments.concat(enforce_schedule(plan, subcontractor))

    if subcontractor.nil?
      adjustments << "No eligible subcontractor available."
      plan[:assumptions] = Array(plan[:assumptions]) + ["Subcontractor to be assigned manually."]
    end

    [plan, adjustments]
  end

  def build_input_context
    {
      lead: @lead.attributes,
      services: Service.all.map(&:attributes),
      pricing_rules: PricingRule.all.map(&:attributes),
      subcontractors: Subcontractor.includes(:subcontractor_availabilities).map do |sub|
        sub.attributes.merge(
          subcontractor_availabilities: sub.subcontractor_availabilities.map(&:attributes)
        )
      end
    }
  end

  def build_openai_payload(input_context)
    {
      lead: input_context[:lead].slice(
        "full_name",
        "email",
        "phone",
        "address_line1",
        "city",
        "state",
        "postal_code",
        "service_requested",
        "notes",
        "urgency_hint"
      ),
      allowed_services: input_context[:services].map { |svc| svc.slice("code", "name") },
      pricing_rules: input_context[:pricing_rules].map do |rule|
        rule.slice("service_code", "min_price_cents", "max_price_cents", "base_price_cents")
      end,
      subcontractors: input_context[:subcontractors].map do |sub|
        {
          id: sub["id"],
          name: sub["name"],
          service_codes: sub["service_codes"],
          is_active: sub["is_active"],
          availabilities: Array(sub["subcontractor_availabilities"] || sub[:subcontractor_availabilities]).map do |slot|
            slot.slice("day_of_week", "window_start", "window_end")
          end
        }
      end,
      business_constraints: {
        schedule_min: "next_business_day_or_later",
        schedule_window: "must_match_availability_if_possible_else_default_09_00-12_00",
        quote_bounds: "total_cents must be within pricing_rules min/max for service",
        subcontractor_eligibility: "subcontractor must include service_code or be null",
        timezone: "America/New_York"
      },
      plan_schema: plan_schema_reference
    }
  end

  def infer_service_code
    request = @lead.service_requested.to_s.downcase
    return "stump_grinding" if request.include?("stump")
    return "trimming" if request.include?("trim")

    "tree_removal"
  end

  def infer_urgency_level
    hint = @lead.urgency_hint.to_s.downcase
    return "high" if hint.include?("asap") || hint.include?("urgent")
    return "medium" if hint.include?("week")

    "low"
  end

  def active_assignment_exists?
    Assignment.joins(job: :lead)
              .where(jobs: { lead_id: @lead.id })
              .where(status: %w[assigned confirmed])
              .exists?
  end

  def select_subcontractor(service_code)
    Subcontractor.where(is_active: true).find do |sub|
      sub.service_codes.include?(service_code)
    end
  end

  def build_schedule(subcontractor)
    date = next_business_day
    window_start = "09:00"
    window_end = "12:00"

    if subcontractor
      availability = availability_for_date(subcontractor, date)

      if availability
        window_start = format_availability_time(availability.window_start)
        window_end = format_availability_time(availability.window_end)
      end
    end

    {
      date: date.iso8601,
      window_start: window_start,
      window_end: window_end
    }
  end

  def enforce_schedule(plan, subcontractor)
    adjustments = []
    schedule = plan[:schedule].is_a?(Hash) ? plan[:schedule] : {}

    next_business = next_business_day
    date = parse_schedule_date(schedule[:date]) || next_business
    if date < next_business
      date = next_business
      adjustments << "Adjusted schedule date to next business day."
    end

    window_start = schedule[:window_start].presence || "09:00"
    window_end = schedule[:window_end].presence || "12:00"

    if subcontractor
      slots = availabilities_for_date(subcontractor, date)
      if slots.any?
        matching_slot = matching_availability_slot(slots, window_start, window_end)
        slot = matching_slot || slots.first
        window_start = format_availability_time(slot.window_start)
        window_end = format_availability_time(slot.window_end)
        adjustments << "Adjusted schedule to match subcontractor availability." if schedule[:date] != date.iso8601 ||
                                                                          schedule[:window_start] != window_start ||
                                                                          schedule[:window_end] != window_end
      else
        next_slot = next_available_slot(subcontractor, date)
        if next_slot
          date = next_slot[:date]
          window_start = format_availability_time(next_slot[:slot].window_start)
          window_end = format_availability_time(next_slot[:slot].window_end)
          adjustments << "Adjusted schedule to next available subcontractor window."
        end
      end
    end

    plan[:schedule] = {
      date: date.iso8601,
      window_start: window_start,
      window_end: window_end
    }

    adjustments
  end

  def availability_for_date(subcontractor, date)
    availabilities_for_date(subcontractor, date).first
  end

  def availabilities_for_date(subcontractor, date)
    subcontractor.subcontractor_availabilities
                 .select { |slot| slot.day_of_week == date.wday }
                 .sort_by(&:window_start)
  end

  def matching_availability_slot(slots, window_start, window_end)
    return if window_start.blank? || window_end.blank?

    slots.find do |slot|
      slot_start = format_availability_time(slot.window_start)
      slot_end = format_availability_time(slot.window_end)
      schedule_within_slot?(window_start, window_end, slot_start, slot_end)
    end
  end

  def schedule_within_slot?(schedule_start, schedule_end, slot_start, slot_end)
    schedule_start_minutes = minutes_since_midnight(schedule_start)
    schedule_end_minutes = minutes_since_midnight(schedule_end)
    slot_start_minutes = minutes_since_midnight(slot_start)
    slot_end_minutes = minutes_since_midnight(slot_end)

    return false unless [schedule_start_minutes, schedule_end_minutes, slot_start_minutes, slot_end_minutes].all?

    schedule_start_minutes >= slot_start_minutes && schedule_end_minutes <= slot_end_minutes
  end

  def minutes_since_midnight(value)
    return if value.blank?
    parts = value.split(":").map(&:to_i)
    return if parts.length < 2

    (parts[0] * 60) + parts[1]
  end

  def format_availability_time(value)
    return "09:00" if value.nil?
    time = value.in_time_zone("America/New_York")
    time.strftime("%H:%M")
  end

  def next_available_slot(subcontractor, start_date)
    (0..14).each do |offset|
      date = start_date + offset
      slot = availability_for_date(subcontractor, date)
      return { date: date, slot: slot } if slot
    end
    nil
  end

  def parse_schedule_date(value)
    return if value.blank?
    Time.zone.parse(value.to_s)&.to_date
  rescue ArgumentError, TypeError
    nil
  end

  def confidence_score(service_code, subcontractor)
    score = 0.5
    score += 0.1 if service_code.present?
    score += 0.1 if subcontractor.present?
    score += 0.1 if @lead.urgency_hint.to_s.strip.empty?
    score += 0.1 if @lead.service_requested.to_s.strip.length >= 8
    score = score.clamp(0.3, 0.9)
    score.round(2)
  end

  def next_business_day
    date = Time.zone.today
    date += 1 while date.saturday? || date.sunday?
    date
  end

  def customer_message(schedule)
    "Thanks for reaching out. We can schedule you on #{schedule[:date]} between #{schedule[:window_start]} and #{schedule[:window_end]}."
  end

  def plan_schema
    {
      "type" => "object",
      "additionalProperties" => false,
      "required" => %w[service_code urgency_level quote schedule subcontractor_id customer_message confidence assumptions],
      "properties" => {
        "service_code" => { "type" => "string" },
        "urgency_level" => { "type" => "string", "enum" => %w[low medium high] },
        "quote" => {
          "type" => "object",
          "additionalProperties" => false,
          "required" => %w[line_items total_cents],
          "properties" => {
            "line_items" => {
              "type" => "array",
              "minItems" => 1,
              "items" => {
                "type" => "object",
                "additionalProperties" => false,
                "required" => %w[description quantity unit_price_cents total_cents],
                "properties" => {
                  "description" => { "type" => "string" },
                  "quantity" => { "type" => "integer" },
                  "unit_price_cents" => { "type" => "integer" },
                  "total_cents" => { "type" => "integer" }
                }
              }
            },
            "total_cents" => { "type" => "integer" }
          }
        },
        "schedule" => {
          "type" => "object",
          "additionalProperties" => false,
          "required" => %w[date window_start window_end],
          "properties" => {
            "date" => { "type" => "string" },
            "window_start" => { "type" => "string" },
            "window_end" => { "type" => "string" }
          }
        },
        "subcontractor_id" => { "type" => %w[string null] },
        "customer_message" => { "type" => "string" },
        "confidence" => { "type" => "number" },
        "assumptions" => { "type" => "array", "items" => { "type" => "string" } }
      }
    }
  end

  def plan_schema_reference
    {
      required_keys: %w[
        service_code
        urgency_level
        quote
        schedule
        subcontractor_id
        customer_message
        confidence
        assumptions
      ],
      quote: {
        line_items: {
          required_keys: %w[description quantity unit_price_cents total_cents]
        },
        total_cents: "integer"
      },
      schedule: {
        date: "YYYY-MM-DD",
        window_start: "HH:MM",
        window_end: "HH:MM"
      },
      subcontractor_id: "string or null",
      additional_properties: false
    }
  end

  def duration_ms_since(start_time)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
  end

  def log_action(agent_run, action_type, status, payload, error_message = nil)
    ActionLog.create!(
      lead: @lead,
      agent_run: agent_run,
      action_type: action_type,
      status: status,
      payload: payload,
      error_message: error_message
    )
  end
end
