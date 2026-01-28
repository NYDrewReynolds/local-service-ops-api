class Lead < ApplicationRecord
  has_many :agent_runs, dependent: :destroy
  has_many :quotes, dependent: :destroy
  has_many :jobs, dependent: :destroy
  has_many :action_logs, dependent: :destroy
  has_many :notifications, dependent: :destroy

  enum :status, {
    new: "new",
    planned: "planned",
    executed: "executed",
    failed: "failed"
  }, prefix: true

  validates :full_name, :address_line1, :city, :state, :postal_code, :service_requested, presence: true
end
