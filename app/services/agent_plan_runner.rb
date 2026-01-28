class AgentPlanRunner
  MAX_SCHEMA_ATTEMPTS = 2

  def initialize(lead:, mode:)
    @lead = lead
    @mode = mode
  end

  def call
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    agent_run = AgentRun.create!(
      lead: @lead,
      status: "started",
      model: "stubbed",
      input_context: build_input_context
    )

    agent_run.update!(status: "validating")

    plan, validation_errors = generate_valid_plan
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
    attempts = 0
    validation_errors = []

    while attempts < MAX_SCHEMA_ATTEMPTS
      attempts += 1
      plan = generate_plan
      validation_errors = JSON::Validator.fully_validate(plan_schema, plan)
      return [plan, []] if validation_errors.empty?
    end

    [plan, validation_errors]
  end

  def generate_plan
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
      confidence: 0.72,
      assumptions: ["Single service visit", "No access restrictions noted"]
    }
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
      plan[:schedule] = build_schedule(subcontractor)
    end

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
      availability = subcontractor.subcontractor_availabilities.find do |slot|
        slot.day_of_week == date.wday
      end

      if availability
        window_start = availability.window_start.strftime("%H:%M")
        window_end = availability.window_end.strftime("%H:%M")
      end
    end

    {
      date: date.iso8601,
      window_start: window_start,
      window_end: window_end
    }
  end

  def next_business_day
    date = Date.current
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
