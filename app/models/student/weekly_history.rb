class Student
  # Deep module producing the ordered series of Medal weeks (Monday→Sunday in
  # America/Sao_Paulo) flagged Full / not-Full against the student's *current*
  # weekly_frequency, plus the streak/lifetime aggregates the two cadence-based
  # Medal families read (ADR-0005). A TrainingSession belongs to the week of its
  # created_at — so backdated log_past! sessions land in the right week —
  # mirroring Student::FrequencyView's bucketing.
  #
  # The current in-progress week is *pending*: it never counts as a miss, and
  # counts as Full only once it crosses the threshold. The weekly streak
  # survives a single isolated missed week (the one-miss freeze) and breaks only
  # on two consecutive misses. Everything is computed live from history — no
  # per-week cadence is stored — so changing weekly_frequency re-judges every
  # past week. Returns empty (zero aggregates) when no cadence is set.
  class WeeklyHistory
    def initialize(student)
      @student = student
    end

    # Whether the student has an explicit weekly cadence. With no cadence the
    # two weekly families stay locked (no fallback, per ADR-0005).
    def cadence?
      weekly_frequency.positive?
    end

    # Best-ever run of consecutive Full weeks, with the one-miss freeze.
    def best_streak
      streaks[:best]
    end

    # The current ongoing run of Full weeks, frozen through a single recent miss
    # and unaffected by the pending current week.
    def current_streak
      streaks[:current]
    end

    # Lifetime count of Full weeks (includes the current week once it crosses).
    def full_weeks_count
      week_states.count { |state| state == :full }
    end

    private
      def streaks
        @streaks ||= compute_streaks
      end

      def compute_streaks
        current = 0
        best = 0
        prev_miss = false

        week_states.each do |state|
          case state
          when :full
            current += 1
            best = [ best, current ].max
            prev_miss = false
          when :miss
            if prev_miss
              # Second miss in a row breaks the streak.
              current = 0
              prev_miss = false
            else
              # First miss is absorbed: the streak freezes (no increment, no
              # reset) but a Full week can still resume it.
              prev_miss = true
            end
            # :pending is neutral — it neither advances nor breaks the streak.
          end
        end

        { best: best, current: current }
      end

      # The Full / :miss / :pending flag for every Medal week from the first
      # week the student trained through the current week. Empty when no cadence
      # is set or the student has never finished a session.
      def week_states
        @week_states ||= build_week_states
      end

      def build_week_states
        return [] unless cadence?
        return [] if counts_by_week.empty?

        (counts_by_week.keys.min..current_week).step(7).map do |week|
          count = counts_by_week[week] || 0
          if week == current_week && count < weekly_frequency
            :pending
          elsif count >= weekly_frequency
            :full
          else
            :miss
          end
        end
      end

      def counts_by_week
        @counts_by_week ||= @student.training_sessions.finished.pluck(:created_at)
          .each_with_object(Hash.new(0)) { |created_at, counts| counts[week_of(created_at)] += 1 }
      end

      def week_of(time)
        time.in_time_zone.to_date.beginning_of_week
      end

      def current_week
        @current_week ||= Time.zone.today.beginning_of_week
      end

      def weekly_frequency
        @student.weekly_frequency.to_i
      end
  end
end
