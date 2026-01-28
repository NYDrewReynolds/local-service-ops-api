module Api
  module V1
    class SubcontractorsController < BaseController
      def index
        subcontractors = Subcontractor.includes(:subcontractor_availabilities).order(:name)
        render_json({ subcontractors: subcontractors.as_json(include: :subcontractor_availabilities) })
      end

      def show
        subcontractor = Subcontractor.includes(:subcontractor_availabilities).find(params[:id])
        render_json({ subcontractor: subcontractor.as_json(include: :subcontractor_availabilities) })
      end
    end
  end
end
