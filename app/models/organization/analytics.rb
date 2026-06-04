class Organization
  # Payload for the trainer Analytics section. Two daily series over a trailing
  # 14-day window, each gap-filled with zeros so silent days render as an empty
  # slot rather than a hole, and bucketed in the app time zone so days line up
  # with how the trainer experiences the calendar:
  #
  # - training_sessions: sessions started per day, split by who kicked them off
  #   (trainer-led vs student-initiated — the ADR-0007 nullable-trainer axis).
  # - periodizations: plans created per day.
  #
  # Built to grow: add sibling series here as the section gains metrics.
  class Analytics
    DAYS = 14

    def initialize(organization, days: DAYS)
      @organization = organization
      @days = days
    end

    def to_h
      { training_sessions: training_sessions_series, periodizations: periodizations_series }
    end

    private
      attr_reader :organization, :days

      def training_sessions_series
        trainer = Hash.new(0)
        student = Hash.new(0)

        TrainingSession.joins(:student)
          .where(students: { organization_id: organization.id })
          .where(created_at: window_start..)
          .pluck(:created_at, :trainer_id)
          .each do |created_at, trainer_id|
            bucket = trainer_id.nil? ? student : trainer
            bucket[created_at.in_time_zone.to_date] += 1
          end

        each_day do |day|
          { date: day.iso8601, label: day.strftime("%d/%m"), trainer: trainer[day], student: student[day] }
        end
      end

      def periodizations_series
        counts = Hash.new(0)

        Periodization.joins(:student)
          .where(students: { organization_id: organization.id })
          .where(created_at: window_start..)
          .pluck(:created_at)
          .each { |created_at| counts[created_at.in_time_zone.to_date] += 1 }

        each_day do |day|
          { date: day.iso8601, label: day.strftime("%d/%m"), count: counts[day] }
        end
      end

      def each_day
        first_day = today - (days - 1)
        (0...days).map { |i| yield(first_day + i) }
      end

      def window_start
        @window_start ||= (today - (days - 1)).in_time_zone.beginning_of_day
      end

      def today
        @today ||= Time.zone.today
      end
  end
end
