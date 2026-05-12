module TrainingSession::Finishable
  extend ActiveSupport::Concern

  STALE_CUTOFF = 8.hours

  included do
    scope :active,   -> { where(finished_at: nil) }
    scope :finished, -> { where.not(finished_at: nil) }
    scope :stale,    -> { active.where("created_at < ?", STALE_CUTOFF.ago) }
  end

  def finish!
    update!(finished_at: Time.current)
  end

  def reopen!
    update!(finished_at: nil)
  end
end
