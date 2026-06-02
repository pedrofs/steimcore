class Student
  # The Medal evaluation engine (ADR-0005). Compares each Medal family's live
  # metric against its tier ladder and inserts a StudentMedal for every
  # newly-crossed tier. Insert-only and idempotent: re-running awards nothing
  # the second time (the in-memory guard plus the unique [student, family, tier]
  # index), and it never deletes — so a later metric drop (a broken streak, a
  # session reopen!, a cadence change) can lower the *current* value but never
  # revokes an earned Medal.
  module Awardable
    extend ActiveSupport::Concern

    class_methods do
      # One-off launch backfill (PRD #145, slice 6). Awards every historical
      # medal across all students and stamps seen_at on the results, so
      # pre-existing achievements appear in full color without a first-visit
      # celebration storm — celebrations stay reserved for post-launch organic
      # earns. Idempotent: evaluate_medals! is insert-only, so re-running awards
      # nothing new and therefore never resets seen_at.
      def backfill_medals!
        find_each { |student| student.evaluate_medals!.each(&:mark_seen!) }
      end
    end

    # Awards newly-crossed tiers across all families and returns the records
    # created this pass (empty when nothing new was earned).
    def evaluate_medals!
      Medal.families.flat_map { |family| award_family(family) }
    end

    private
      def award_family(family)
        value = family.metric(self)
        return [] if value.nil?

        already_earned = student_medals.where(family: family.key).pluck(:tier).to_set
        family.tiers.filter_map do |tier|
          next if value < tier || already_earned.include?(tier)

          student_medals.create!(
            family: family.key,
            tier: tier,
            value_snapshot: value,
            earned_at: Time.current
          )
        end
      end
  end
end
