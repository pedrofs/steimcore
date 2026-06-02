class StudentMedal < ApplicationRecord
  belongs_to :student

  # Organic earns land with seen_at = NULL; the backfill stamps it so
  # pre-existing achievements never celebrate (ADR-0005, PRD #145). The unseen
  # set drives the nav dot and the Medalhas celebration sequence (slice 4).
  scope :unseen, -> { where(seen_at: nil) }

  validates :family, presence: true
  validates :tier, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :value_snapshot, presence: true, numericality: { only_integer: true }
  # The unique [student_id, family, tier] index is what makes evaluation
  # idempotent (ADR-0005); this validation surfaces the same constraint with a
  # friendly error before the database backstop fires.
  validates :tier, uniqueness: { scope: [ :student_id, :family ] }

  # Stamps seen_at once a medal's celebration has finished playing on the
  # Medalhas page (PRD #145, slice 4). Idempotent: marking an already-seen
  # medal leaves its original timestamp untouched.
  def mark_seen!
    update!(seen_at: Time.current) unless seen_at
  end
end
