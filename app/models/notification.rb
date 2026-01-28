class Notification < ApplicationRecord
  belongs_to :lead
  belongs_to :job, optional: true

  enum :channel, {
    email: "email",
    sms: "sms"
  }, prefix: true

  enum :status, {
    queued: "queued",
    sent: "sent",
    failed: "failed",
    stubbed: "stubbed"
  }, prefix: true
end
