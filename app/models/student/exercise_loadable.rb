# Read side of per-exercise weight tracking. Exposes the student's current
# (most recent) weight per movement so live-session and workout views can show
# what was used last time. See ExerciseLoad for the keying rationale.
module Student::ExerciseLoadable
  extend ActiveSupport::Concern

  included do
    has_many :exercise_loads, dependent: :destroy
  end

  # Latest ExerciseLoad per movement, keyed by +exercise_key+. One row per
  # movement (DISTINCT ON), newest wins (UUIDv7 id DESC).
  def current_loads
    exercise_loads
      .select("DISTINCT ON (exercise_key) *")
      .order("exercise_key, id DESC")
      .index_by(&:exercise_key)
  end

  # Current weight string for a single movement name, or nil if never set or
  # since cleared (a blank latest entry reads as nil).
  def current_load_for(exercise_name)
    current_loads[ExerciseLoad.normalize_name(exercise_name)]&.value.presence
  end
end
