class Workout < ApplicationRecord
  belongs_to :periodization_version
  has_many :training_sessions, dependent: :nullify

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true }
  validate :validate_blocks_schema

  default_scope -> { order(:position) }

  # Exercise names live in `blocks`, so a blocks change on a completed version
  # alters the set of names linking reconciles — but it never transitions the
  # version's status, so PeriodizationVersion's status-only trigger misses it.
  # Re-link here whenever blocks change on an already-completed version (inline
  # trainer edits and in-place apply_patch! both land as blocks writes). The
  # job is idempotent and serialized, so a redundant enqueue is harmless.
  after_commit :relink_version_exercises, on: [ :create, :update ]

  private
    def validate_blocks_schema
      Blocks.errors_for(blocks).each { |message| errors.add(:blocks, message) }
    end

    def relink_version_exercises
      return unless saved_change_to_blocks?
      return unless periodization_version.status == "completed"

      LinkExercisesJob.perform_later(periodization_version)
    end
end
