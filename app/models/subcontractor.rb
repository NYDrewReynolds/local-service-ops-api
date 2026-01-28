class Subcontractor < ApplicationRecord
  has_many :subcontractor_availabilities, dependent: :destroy
  has_many :assignments, dependent: :destroy

  validates :name, :phone, presence: true
end
