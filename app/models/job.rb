class Job < ApplicationRecord
  belongs_to :lead
  belongs_to :quote
  has_many :assignments, dependent: :destroy
  has_one :notification, dependent: :destroy

  enum :status, {
    scheduled: "scheduled",
    dispatched: "dispatched",
    completed: "completed",
    canceled: "canceled"
  }, prefix: true
end
