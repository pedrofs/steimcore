module Student::SelfServeTrainable
  extend ActiveSupport::Concern

  # The student's current in-progress session — trainer- or student-initiated.
  # The home uses this to route the student back into a live session (resume)
  # rather than offer a second start; nil when nothing is active.
  def active_training_session
    training_sessions.active.first
  end

  # Begins a student-initiated session (no trainer attached) on the suggested
  # workout, or an explicitly chosen +workout+. Enforces the rest-day rule
  # server-side first — raising in the same string-message style start! uses, so
  # the controller can rescue it into a friendly redirect — then delegates to the
  # generalized TrainingSession.start!, which applies the remaining eligibility
  # guards and the one-active-per-student index. See ADR-0005.
  def start_training_session!(workout: nil)
    raise "Hoje é dia de descanso — bom treino na segunda! 🧘" if Student::RestDay.today?

    TrainingSession.start!(student: self, workout: workout)
  end

  # Whether the home should offer a self-start today: not a rest day and the
  # student is eligible (active periodization with a completed current version
  # that has workouts — encoded by next_workout_for returning a workout).
  def self_start_allowed_today?
    !Student::RestDay.today? && TrainingSession.next_workout_for(self).present?
  end
end
