class Quote < ApplicationRecord
  belongs_to :lead
  belongs_to :agent_run
  has_many :quote_line_items, dependent: :destroy
  has_one :job, dependent: :destroy

  validates :subtotal_cents, :total_cents, :confidence, presence: true
end
