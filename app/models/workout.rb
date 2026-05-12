class Workout < ApplicationRecord
  belongs_to :periodization_version
  has_many :training_sessions, dependent: :nullify

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true }
  validate :validate_blocks_schema

  default_scope -> { order(:position) }

  private
    def validate_blocks_schema
      Blocks.errors_for(blocks).each { |message| errors.add(:blocks, message) }
    end
end
