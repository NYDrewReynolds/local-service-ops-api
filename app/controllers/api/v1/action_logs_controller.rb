module Api
  module V1
    class ActionLogsController < BaseController
      def index
        lead = Lead.find(params[:lead_id])
        logs = lead.action_logs.order(:created_at)
        render_json({ action_logs: logs })
      end

      def timeline
        lead = Lead.find(params[:lead_id])
        logs = lead.action_logs.order(:created_at).map do |log|
          {
            type: "action_log",
            id: log.id,
            action_type: log.action_type,
            status: log.status,
            payload: log.payload,
            error_message: log.error_message,
            created_at: log.created_at
          }
        end

        runs = lead.agent_runs.order(:created_at).map do |run|
          {
            type: "agent_run",
            id: run.id,
            status: run.status,
            model: run.model,
            validation_errors: run.validation_errors,
            duration_ms: run.duration_ms,
            created_at: run.created_at
          }
        end

        timeline = (logs + runs).sort_by { |event| event[:created_at] }
        render_json({ timeline: timeline })
      end
    end
  end
end
