class ActionLog < ApplicationRecord
  belongs_to :lead
  belongs_to :agent_run, optional: true

  enum :status, {
    ok: "ok",
    error: "error"
  }, prefix: true
end
