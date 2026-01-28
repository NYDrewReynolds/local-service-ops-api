module Api
  module V1
    class AgentRunsController < BaseController
      def create
        lead = Lead.find(params[:lead_id])
        mode = params[:mode].presence || "execute"

        result = AgentPlanRunner.new(lead: lead, mode: mode).call
        render_json(result, status: :created)
      end

      def show
        agent_run = AgentRun.find(params[:id])
        render_json({ agent_run: agent_run })
      end
    end
  end
end
