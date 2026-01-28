class QuoteLineItem < ApplicationRecord
  belongs_to :quote

  validates :description, :quantity, :unit_price_cents, :total_cents, presence: true
end
