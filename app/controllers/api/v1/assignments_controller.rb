module Api
  module V1
    class AssignmentsController < BaseController
      def index
        assignments = Assignment.includes(:subcontractor, job: :lead).order(created_at: :desc)
        render_json({ assignments: assignments.as_json(include: { subcontractor: {}, job: { include: :lead } }) })
      end

      def show
        assignment = Assignment.includes(:subcontractor, job: :lead).find(params[:id])
        render_json({ assignment: assignment.as_json(include: { subcontractor: {}, job: { include: :lead } }) })
      end

      def update
        assignment = Assignment.includes(job: :lead).find(params[:id])
        assignment.update!(assignment_params)
        log_action_for(assignment)
        render_json({ assignment: assignment.as_json(include: { subcontractor: {}, job: { include: :lead } }) })
      end

      private

      def assignment_params
        params.require(:assignment).permit(:status)
      end

      def log_action_for(assignment)
        return unless assignment.status == "declined"

        ActionLog.create!(
          lead: assignment.job.lead,
          agent_run: nil,
          action_type: "assignment_declined",
          status: "ok",
          payload: { assignment_id: assignment.id, subcontractor_id: assignment.subcontractor_id }
        )
      end
    end
  end
end
