module Api
  module V1
    class JobsController < BaseController
      def index
        jobs = Job.includes(assignments: :subcontractor, :notification, :lead).order(created_at: :desc)
        render_json({ jobs: jobs.as_json(include: { assignments: { include: :subcontractor }, notification: {} }) })
      end

      def show
        job = Job.includes(assignments: :subcontractor, :notification, :lead).find(params[:id])
        render_json({ job: job.as_json(include: { assignments: { include: :subcontractor }, notification: {} }) })
      end

      def update
        job = Job.find(params[:id])
        job.update!(job_params)
        render_json({ job: job })
      end

      private

      def job_params
        params.require(:job).permit(:status, :scheduled_date, :scheduled_window_start, :scheduled_window_end)
      end
    end
  end
end
