class Student
  # Read-only composition powering the student "Treinos" tab
  # (Student::WorkoutsController#index). Lists the Workouts of the student's
  # Active periodization's Current version, in prescribed (position) order, for a
  # read-only "browse my whole plan" view.
  #
  # Sources exclusively from the promoted current_version — generating, pending,
  # draft, and failed PeriodizationVersions stay invisible to the student. When
  # there is no readable plan (no Active periodization, no Current version, or
  # zero workouts) it returns an empty list, and the page renders the unified
  # "plan not ready" empty state.
  #
  # Sibling of Student::DashboardView and Student::FrequencyView. Carries no
  # Training session history and no session-derived "next workout" — "what's
  # next" stays on the home dashboard; this is the plan in full.
  class WorkoutsView
    def initialize(student)
      @student = student
    end

    def to_h
      { workouts: workouts.map { |workout| workout_payload(workout) } }
    end

    private
      def workouts
        @student.active_periodization&.current_version&.workouts&.order(:position) || []
      end

      def workout_payload(workout)
        {
          id: workout.id,
          name: workout.name,
          position: workout.position,
          blocks: workout.blocks
        }
      end
  end
end
