class Student
  # Windowed, calendar-aligned view of a student's finished training sessions
  # used to render the Frequência grid on the student show page. Buckets sessions
  # by their +created_at+ date in the configured time zone.
  class FrequencyView
    WEEKS = 26

    def initialize(student)
      @student = student
    end

    def to_h
      {
        window_start: window_start,
        window_end: window_end,
        today: today,
        days: build_days
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
        grouped = sessions.group_by { |session| session.created_at.in_time_zone.to_date }
        (window_start..window_end).map do |date|
          {
            date: date,
            sessions: (grouped[date] || []).map { |session| { id: session.id, created_at: session.created_at } }
          }
        end
      end

      def sessions
        range = window_start.in_time_zone.beginning_of_day..window_end.in_time_zone.end_of_day
        @sessions ||= @student.training_sessions.finished.where(created_at: range).order(:created_at).to_a
      end
  end
end
