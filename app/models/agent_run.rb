class AgentRun < ApplicationRecord
  belongs_to :lead
  has_one :quote, dependent: :destroy
  has_many :action_logs, dependent: :destroy

  enum :status, {
    started: "started",
    validating: "validating",
    validated: "validated",
    executing: "executing",
    succeeded: "succeeded",
    failed: "failed"
  }, prefix: true
end
