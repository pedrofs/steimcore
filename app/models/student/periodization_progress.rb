class Student
  # Value object answering how far a student is through their Active
  # periodization. Owns the rules from CONTEXT.md ("Periodization target",
  # "Sessions remaining") so the dashboard queue, the row badge, and any future
  # surface share one definition rather than duplicating the math. See ADR 0002.
  class PeriodizationProgress
    def initialize(student)
      @student = student
    end

    # False when the target is undefined: no Active periodization, null/zero
    # weekly_frequency, or a Current version without a periodization_length_weeks.
    # Every other query returns nil/false when this is false.
    def applicable?
      !target.nil?
    end

    def target
      return nil if active_periodization.nil?
      return nil if weekly_frequency.nil? || weekly_frequency.zero?

      length = current_version&.periodization_length_weeks
      return nil if length.nil?

      length * weekly_frequency
    end

    # Finished sessions across every version of the Active periodization,
    # including superseded ones — the clock is per-Periodization. Sessions on
    # archived periodizations belong to other periodizations and don't count.
    def sessions_done
      return nil unless applicable?

      @student.training_sessions
              .where.not(finished_at: nil)
              .where(periodization_version_id: active_periodization.versions.select(:id))
              .count
    end

    def sessions_remaining
      return nil unless applicable?

      target - sessions_done
    end

    def overdue?
      applicable? && sessions_remaining.negative?
    end

    private
      def active_periodization
        @student.active_periodization
      end

      def current_version
        active_periodization&.current_version
      end

      def weekly_frequency
        @student.weekly_frequency
      end
  end
end
