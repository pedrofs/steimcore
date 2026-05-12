class TrainingSession < ApplicationRecord
  belongs_to :student
  belongs_to :trainer, class_name: "User"
  belongs_to :workout, optional: true

  validates :workout_name_snapshot, presence: true
  validates :workout_position_snapshot, presence: true, numericality: { only_integer: true }
  validate :validate_blocks_snapshot_schema

  private
    def validate_blocks_snapshot_schema
      Workout::Blocks.errors_for(blocks_snapshot).each { |message| errors.add(:blocks_snapshot, message) }
    end
end
