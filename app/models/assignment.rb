class Assignment < ApplicationRecord
  belongs_to :job
  belongs_to :subcontractor

  enum :status, {
    assigned: "assigned",
    confirmed: "confirmed",
    declined: "declined"
  }, prefix: true
end
