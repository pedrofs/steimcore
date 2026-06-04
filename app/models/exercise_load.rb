# One row per "the weight for this movement was set", recorded during a live
# training session. The weight is never LLM-generated — the trainer or student
# defines it, and the most recent entry per (student, movement) becomes the
# current value future sessions read back.
#
# Movements (standalone exercise blocks and group items alike) carry no stable
# id in the +blocks+ JSONB, so weight is keyed by the normalized movement name
# (+exercise_key+). This survives workout edits and periodization version forks,
# which rebuild workout rows but keep names.
class ExerciseLoad < ApplicationRecord
  # +exercise_key+ is the **Normalized key** — the same identity the Exercise
  # catalog resolves names against, so per-student weight history can't drift
  # from the catalog. The folding logic lives in `Normalizable`.
  include Normalizable

  belongs_to :student
  belongs_to :training_session, optional: true

  validates :exercise_name, presence: true
  validates :exercise_key, presence: true
  # +value+ is intentionally allowed to be blank: a blank entry is a *clearance*
  # — the trainer/student removed the weight, so the latest (blank) value means
  # "no current load". Reads treat a blank latest as nil (see ExerciseLoadable).
end
