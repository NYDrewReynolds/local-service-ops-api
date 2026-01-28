class PlanExecutor
  def initialize(lead:, agent_run:, plan:)
    @lead = lead
    @agent_run = agent_run
    @plan = plan.deep_symbolize_keys
  end

  def call
    result = {}

    ActiveRecord::Base.transaction do
      quote = create_quote
      result[:quote] = quote
      log_action("create_quote", "ok", { quote_id: quote.id })

      job = create_job(quote)
      result[:job] = job
      log_action("create_job", "ok", { job_id: job.id })

      assignment = create_assignment(job)
      result[:assignment] = assignment
      log_action("assign_subcontractor", "ok", { assignment_id: assignment.id })

      notification = create_notification(job)
      result[:notification] = notification
      log_action("send_notification", "ok", { notification_id: notification.id })
    end

    { ok: true }.merge(result)
  rescue StandardError => error
    log_action("execute_plan", "error", { message: error.message }, error.message)
    { ok: false, error: error.message }
  end

  private

  def create_quote
    line_items = @plan.dig(:quote, :line_items) || []
    subtotal_cents = line_items.sum { |item| item[:total_cents].to_i }
    total_cents = @plan.dig(:quote, :total_cents).to_i

    quote = Quote.create!(
      lead: @lead,
      agent_run: @agent_run,
      subtotal_cents: subtotal_cents,
      total_cents: total_cents,
      confidence: @plan[:confidence].to_f
    )

    line_items.each do |item|
      QuoteLineItem.create!(
        quote: quote,
        description: item[:description],
        quantity: item[:quantity],
        unit_price_cents: item[:unit_price_cents],
        total_cents: item[:total_cents]
      )
    end

    quote
  end

  def create_job(quote)
    schedule = @plan[:schedule]
    Job.create!(
      lead: @lead,
      quote: quote,
      scheduled_date: Date.parse(schedule[:date]),
      scheduled_window_start: schedule[:window_start],
      scheduled_window_end: schedule[:window_end],
      status: "scheduled"
    )
  end

  def create_assignment(job)
    Assignment.create!(
      job: job,
      subcontractor_id: @plan[:subcontractor_id],
      status: "assigned"
    )
  end

  def create_notification(job)
    Notification.create!(
      lead: @lead,
      job: job,
      channel: "email",
      to: @lead.email.presence || "unknown@example.com",
      subject: "Service scheduled",
      body: @plan[:customer_message],
      status: "stubbed"
    )
  end

  def log_action(action_type, status, payload, error_message = nil)
    ActionLog.create!(
      lead: @lead,
      agent_run: @agent_run,
      action_type: action_type,
      status: status,
      payload: payload,
      error_message: error_message
    )
  end
end
