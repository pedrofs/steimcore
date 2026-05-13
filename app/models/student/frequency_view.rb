class Student
  # Windowed, calendar-aligned view of a student's finished training sessions
  # used to render the Frequência grid on the student show page. Buckets sessions
  # by their +created_at+ date in the configured time zone and assigns each
  # distinct PeriodizationVersion in the window a deterministic palette slot
  # (chronological-first-seen) so the UI can color cells and render a legend.
  class FrequencyView
    WEEKS = 26
    PALETTE_SIZE = 5

    def initialize(student)
      @student = student
    end

    def to_h
      {
        window_start: window_start,
        window_end: window_end,
        today: today,
        days: build_days,
        versions: build_versions
      }
    end

    private
      def today
        @today ||= Time.zone.today
      end

      def window_end
        @window_end ||= today.end_of_week
      end

      def window_start
        @window_start ||= (today - (WEEKS - 1).weeks).beginning_of_week
      end

      def build_days
        grouped = sessions.group_by { |session| session_date(session) }
        (window_start..window_end).map do |date|
          {
            date: date,
            sessions: (grouped[date] || []).map { |session| session_payload(session) }
          }
        end
      end

      def session_payload(session)
        version_id = session.periodization_version_id
        {
          id: session.id,
          created_at: session.created_at,
          periodization_version_id: version_id,
          palette_slot: palette_slot_for(version_id),
          workout_name_snapshot: session.workout_name_snapshot,
          workout_position_snapshot: session.workout_position_snapshot,
          trainer_email_prefix: session.trainer.email_address.split("@").first
        }
      end

      def build_versions
        chronological_version_ids.each_with_index.map do |version_id, index|
          version = versions_by_id[version_id]
          dates = sessions_by_version_id[version_id].map { |s| session_date(s) }
          {
            id: version_id,
            number: index + 1,
            periodization_id: version.periodization_id,
            palette_slot: index % PALETTE_SIZE,
            range_start: dates.min,
            range_end: dates.max,
            is_current: current_version_ids.include?(version_id)
          }
        end
      end

      def palette_slot_for(version_id)
        return nil if version_id.nil?
        index = chronological_version_ids.index(version_id)
        return nil if index.nil?
        index % PALETTE_SIZE
      end

      def chronological_version_ids
        @chronological_version_ids ||= sessions.filter_map(&:periodization_version_id).uniq
      end

      def sessions_by_version_id
        @sessions_by_version_id ||= sessions.group_by(&:periodization_version_id)
      end

      def versions_by_id
        @versions_by_id ||= PeriodizationVersion.where(id: chronological_version_ids).index_by(&:id)
      end

      def current_version_ids
        @current_version_ids ||= Periodization
                                 .where(current_version_id: chronological_version_ids, archived_at: nil)
                                 .pluck(:current_version_id)
      end

      def session_date(session)
        session.created_at.in_time_zone.to_date
      end

      def sessions
        range = window_start.in_time_zone.beginning_of_day..window_end.in_time_zone.end_of_day
        @sessions ||= @student.training_sessions.finished.where(created_at: range).includes(:trainer).order(:created_at).to_a
      end
  end
end
