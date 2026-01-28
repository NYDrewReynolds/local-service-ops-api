class PricingRule < ApplicationRecord
  validates :service_code, :min_price_cents, :max_price_cents, :base_price_cents, presence: true
end
