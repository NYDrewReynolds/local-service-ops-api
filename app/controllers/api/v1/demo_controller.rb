module Api
  module V1
    class DemoController < BaseController
      def populate
        Rails.application.load_seed
        render_json({ ok: true })
      end

      def reset
        return render_json({ error: "Reset disabled" }, status: :forbidden) if Rails.env.production?

        ActiveRecord::Base.transaction do
          ActionLog.delete_all
          Notification.delete_all
          Assignment.delete_all
          Job.delete_all
          QuoteLineItem.delete_all
          Quote.delete_all
          AgentRun.delete_all
          Lead.delete_all
          SubcontractorAvailability.delete_all
          Subcontractor.delete_all
          PricingRule.delete_all
          Service.delete_all
        end

        render_json({ ok: true })
      end
    end
  end
end
