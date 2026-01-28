module Api
  module V1
    class LeadsController < BaseController
      def index
        leads = Lead.order(created_at: :desc)
        render_json({ leads: leads })
      end

      def show
        lead = Lead.find(params[:id])
        render_json({ lead: lead })
      end

      def create
        lead = Lead.create!(lead_params)
        render_json({ lead: lead }, status: :created)
      end

      def update
        lead = Lead.find(params[:id])
        lead.update!(lead_params)
        render_json({ lead: lead })
      end

      private

      def lead_params
        params.require(:lead).permit(
          :full_name,
          :email,
          :phone,
          :address_line1,
          :address_line2,
          :city,
          :state,
          :postal_code,
          :service_requested,
          :notes,
          :urgency_hint,
          :status
        )
      end
    end
  end
end
