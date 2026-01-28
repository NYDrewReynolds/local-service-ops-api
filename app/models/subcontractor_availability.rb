class SubcontractorAvailability < ApplicationRecord
  belongs_to :subcontractor

  validates :day_of_week, :window_start, :window_end, presence: true
end
