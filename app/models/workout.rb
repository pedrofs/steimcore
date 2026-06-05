class Workout < ApplicationRecord
  include Blockable

  belongs_to :periodization_version
  has_many :training_sessions, dependent: :nullify

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true }

  default_scope -> { order(:position) }

  # Exercise names live in `blocks`, so a blocks change on a completed version
  # alters the set of names linking reconciles — but it never transitions the
  # version's status, so PeriodizationVersion's status-only trigger misses it.
  # Re-link here whenever blocks change on an already-completed version (inline
  # trainer edits and in-place apply_patch! both land as blocks writes). The
  # job is idempotent and serialized, so a redundant enqueue is harmless.
  after_commit :relink_version_exercises, on: [ :create, :update ]

  # Every exercise-name reference in this workout's blocks, **with repeats** — an
  # `exercise` block contributes its name, a `group` block one per item. The
  # repeats are intentional: usage ranking counts total references, so an exercise
  # used twice in one workout (e.g. warmup + main set) counts twice. Mirrors
  # PeriodizationVersion::Linkable#names_in, which instead dedups by normalized key.
  def exercise_names
    Array(blocks).flat_map { |block| block_names_in(block) }
  end

  private
    def block_names_in(block)
      case block["kind"]
      when "exercise" then Array(block["name"])
      when "group"    then Array(block["items"]).filter_map { |item| item["name"] }
      else []
      end
    end

    def validate_blocks_schema
      Blocks.errors_for(blocks).each { |message| errors.add(:blocks, message) }
    end

    def relink_version_exercises
      return unless saved_change_to_blocks?
      return unless periodization_version.status == "completed"

      LinkExercisesJob.perform_later(periodization_version)
    end
end
