class Workout < ApplicationRecord
  belongs_to :periodization_version

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true }

  default_scope -> { order(:position) }
end
