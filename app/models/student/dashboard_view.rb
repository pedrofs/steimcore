class Student
  # Read-only composition powering the authenticated student dashboard
  # (Student::HomeController#show). Bundles everything a student sees on their
  # home screen into one payload:
  #
  #   * greeting state  — did they train today, and which workout was it
  #   * next workout    — the auto-picked upcoming workout + an exercise teaser
  #   * progress        — how far through the active periodization (PeriodizationProgress)
  #   * calendar        — a 5-week (35-day), week-aligned binary heatmap of finished sessions
  #
  # Sibling of Student::FrequencyView (the 26-week trainer-facing grid): this one
  # is leaner, mobile-first, and binary (trained / not) rather than colored by
  # periodization version.
  class DashboardView
    WEEKS = 5
    PREVIEW_EXERCISES = 4

    def initialize(student)
      @student = student
    end

    def to_h
      {
        first_name: first_name,
        today: today.iso8601,
        trained_today: trained_today?,
        today_workout_name: today_workout_name,
        next_workout: next_workout_payload,
        progress: progress_payload,
        calendar: { days: calendar_days }
      }
    end

    private
      def first_name
        @student.name.to_s.split.first || @student.name
      end

      def today
        @today ||= Time.zone.today
      end

      def trained_today?
        today_sessions.any?
      end

      def today_workout_name
        today_sessions.last&.workout_name_snapshot
      end

      def next_workout_payload
        workout = TrainingSession.next_workout_for(@student)
        return nil if workout.nil?

        exercises = exercises_in(workout.blocks)
        {
          name: workout.name,
          position: workout.position,
          total_exercises: exercises.size,
          preview: exercises.first(PREVIEW_EXERCISES)
        }
      end

      # Flattens the workout's blocks into a flat list of { name, detail } for the
      # teaser. Group blocks contribute each of their items; freeform blocks have
      # no discrete exercises and are skipped.
      def exercises_in(blocks)
        Array(blocks).flat_map do |block|
          case block["kind"]
          when "exercise"
            [ { name: block["name"], detail: block["prescription"] } ]
          when "group"
            Array(block["items"]).map { |item| { name: item["name"], detail: item["prescription"] } }
          else
            []
          end
        end
      end

      def progress_payload
        progress = Student::PeriodizationProgress.new(@student)
        return nil unless progress.applicable?

        done = progress.sessions_done
        target = progress.target
        {
          sessions_done: done,
          target: target,
          sessions_remaining: progress.sessions_remaining,
          percent: target.zero? ? 0 : [ (done * 100.0 / target).round, 100 ].min,
          length_weeks: @student.active_periodization.current_version.periodization_length_weeks
        }
      end

      def calendar_days
        by_date = window_sessions.group_by { |session| session_date(session) }
        (window_start..window_end).map do |date|
          sessions = by_date[date] || []
          {
            date: date.iso8601,
            trained: sessions.any?,
            is_future: date > today,
            sessions: sessions.map { |session| session_summary(session) }
          }
        end
      end

      def session_summary(session)
        {
          id: session.id,
          workout_name: session.workout_name_snapshot,
          exercises: exercises_in(session.blocks_snapshot)
        }
      end

      def window_end
        @window_end ||= today.end_of_week
      end

      def window_start
        @window_start ||= (today - (WEEKS - 1).weeks).beginning_of_week
      end

      def window_sessions
        range = window_start.in_time_zone.beginning_of_day..window_end.in_time_zone.end_of_day
        @window_sessions ||= @student.training_sessions.finished.where(created_at: range).order(:created_at).to_a
      end

      def today_sessions
        @today_sessions ||= window_sessions.select { |session| session_date(session) == today }
      end

      def session_date(session)
        session.created_at.in_time_zone.to_date
      end
  end
end
