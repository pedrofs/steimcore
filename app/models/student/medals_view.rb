class Student
  # Props for the student-facing Medalhas page: one entry per Medal family,
  # collapsed to the student's highest Earned medal, plus the full tier ladder
  # with each tier's earned/locked state, and the ordered queue of unseen medals
  # the page celebrates on load. Read-only — building the queue never marks
  # anything seen (that happens per medal via the seen sub-resource).
  class MedalsView
    def initialize(student)
      @student = student
    end

    def to_h
      {
        families: Medal.families.map { |family| family_payload(family) },
        unseen_medals: unseen_payload
      }
    end

    private
      # The celebration queue: every unseen medal, in earned_at order, with a
      # fixed family order (registry order) then tier breaking same-instant ties
      # so a backfill-style burst plays deterministically. Each entry carries the
      # medal id (to mark it seen) plus everything the Medal component renders.
      def unseen_payload
        @student.student_medals.unseen
          .sort_by { |medal| [ medal.earned_at, family_order.fetch(medal.family, family_order.size), medal.tier ] }
          .map { |medal| celebration_entry(medal) }
      end

      def celebration_entry(medal)
        family = Medal.find(medal.family)
        {
          id: medal.id,
          family: family.key,
          name: family.name,
          color: family.color,
          unit: family.unit,
          count: medal.tier,
          tier_index: family.tiers.index(medal.tier) || 0,
          tier_count: family.tiers.length
        }
      end

      def family_order
        @family_order ||= Medal.families.each_with_index.to_h { |family, index| [ family.key, index ] }
      end

      def family_payload(family)
        earned = earned_by_family[family.key] || []
        earned_by_tier = earned.index_by(&:tier)
        # `current_value` is the live "now" value (e.g. the current streak);
        # `peak_value` is the awarding metric (e.g. the best-ever streak), which
        # the snapshot ceiling backs up so the record survives a metric drop.
        current_value = family.current_metric(@student)
        peak_value = family.metric(@student)

        {
          key: family.key,
          name: family.name,
          color: family.color,
          unit: family.unit,
          explanation: family.explanation,
          locked: earned.empty?,
          current_value: current_value,
          # Best-ever value reached (ADR-0005): the highest of the live peak,
          # the snapshots taken at award time (preserves the record after a
          # streak break / cadence change), and the current value as a floor.
          best_value: [ peak_value, *earned.map(&:value_snapshot), current_value ].compact.max,
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
