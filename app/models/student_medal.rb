class StudentMedal < ApplicationRecord
  belongs_to :student

  validates :family, presence: true
  validates :tier, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :value_snapshot, presence: true, numericality: { only_integer: true }
  # The unique [student_id, family, tier] index is what makes evaluation
  # idempotent (ADR-0005); this validation surfaces the same constraint with a
  # friendly error before the database backstop fires.
  validates :tier, uniqueness: { scope: [ :student_id, :family ] }
end
