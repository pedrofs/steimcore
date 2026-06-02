class Student
  # Props for the student-facing Medalhas page: one entry per Medal family,
  # collapsed to the student's highest Earned medal, plus the full tier ladder
  # with each tier's earned/locked state. Read-only — never marks anything seen.
  class MedalsView
    def initialize(student)
      @student = student
    end

    def to_h
      { families: Medal.families.map { |family| family_payload(family) } }
    end

    private
      def family_payload(family)
        earned = earned_by_family[family.key] || []
        earned_by_tier = earned.index_by(&:tier)
        current_value = family.metric(@student)
        best_value = earned.map(&:value_snapshot).max

        {
          key: family.key,
          name: family.name,
          color: family.color,
          unit: family.unit,
          explanation: family.explanation,
          locked: earned.empty?,
          current_value: current_value,
          # Peak metric ever reached (ADR-0005). Falls back to the live value
          # when nothing's earned yet so the detail sheet still reads sensibly.
          best_value: best_value || current_value,
          highest_tier: earned.map(&:tier).max,
          tiers: family.tiers.map do |tier|
            medal = earned_by_tier[tier]
            { value: tier, earned: medal.present?, earned_at: medal&.earned_at }
          end
        }
      end

      def earned_by_family
        @earned_by_family ||= @student.student_medals.group_by(&:family)
      end
  end
end
