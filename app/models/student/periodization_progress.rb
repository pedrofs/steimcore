class Student
  # Value object answering how far a student is through a periodization. Owns
  # the rules from CONTEXT.md ("Periodization target", "Sessions remaining")
  # so the dashboard queue, the row badge, and any future surface share one
  # definition rather than duplicating the math. See ADR 0002.
  #
  # Defaults to the student's Active periodization (the dashboard's only
  # caller), but also accepts an archived periodization so the show page can
  # surface historical progress.
  class PeriodizationProgress
    DAYS_PER_WEEK = 5

    def initialize(student, periodization: student.active_periodization)
      @student = student
      @periodization = periodization
    end

    # False when the target is undefined: no periodization, or a Current
    # version without a periodization_length_weeks. A null/zero
    # weekly_frequency does not make the target undefined — it falls back to
    # DAYS_PER_WEEK so the show page can still draw a sessions-remaining bar
    # for students whose weekly cadence isn't set. (The dashboard's
    # periodization_overdue/due scopes intentionally exclude those students
    # in SQL; see Student.)
    def applicable?
      !target.nil?
    end

    def target
      return nil if @periodization.nil?

      length = current_version&.periodization_length_weeks
      return nil if length.nil?

      length * effective_weekly_frequency
    end

    # Finished sessions across every version of this periodization, including
    # superseded ones — the clock is per-Periodization. Sessions on other
    # periodizations belong to those periodizations and don't count.
    def sessions_done
      return nil unless applicable?

      @student.training_sessions
              .where.not(finished_at: nil)
              .where(periodization_version_id: @periodization.versions.select(:id))
              .count
    end

    def sessions_remaining
      return nil unless applicable?

      target - sessions_done
    end

    def overdue?
      applicable? && sessions_remaining.negative?
    end

    # Within 5 sessions of finishing the dose: time to plan the next
    # Periodization. Mutually exclusive with overdue? by construction.
    def due?
      applicable? && sessions_remaining.between?(0, 4)
    end

    private
      def current_version
        @periodization&.current_version
      end

      def weekly_frequency
        @student.weekly_frequency
      end

      # Null or zero collapse to the same "unset" state; both fall back to
      # DAYS_PER_WEEK. Mirrors the null/zero handling in Student's inactive
      # cutoff (see app/models/student.rb).
      def effective_weekly_frequency
        return DAYS_PER_WEEK if weekly_frequency.nil? || weekly_frequency.zero?

        weekly_frequency
      end
  end
end
