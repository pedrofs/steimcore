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
      { workouts: workout_payloads }
    end

    private
      def workouts
        @workouts ||= @student.active_periodization&.current_version&.workouts&.order(:position)&.to_a || []
      end

      # Enrich every workout's blocks with catalog media in a single BlockMedia
      # pass: concatenate all blocks across the tab's workouts, resolve once, then
      # split the result back per workout by length. One bulk resolve keeps the
      # query count bounded by distinct exercise keys, not by how many workouts
      # are on the page (no N+1) — calling with_media per workout would re-resolve
      # for each one.
      def workout_payloads
        enriched = BlockMedia.with_media(workouts.flat_map { |workout| Array(workout.blocks) })

        offset = 0
        workouts.map do |workout|
          length = Array(workout.blocks).length
          blocks = enriched.slice(offset, length) || []
          offset += length
          {
            id: workout.id,
            name: workout.name,
            position: workout.position,
            blocks: blocks
          }
        end
      end
  end
end
