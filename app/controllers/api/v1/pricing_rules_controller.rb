module Api
  module V1
    class PricingRulesController < BaseController
      def index
        pricing_rules = PricingRule.order(:service_code)
        render_json({ pricing_rules: pricing_rules })
      end
    end
  end
end
