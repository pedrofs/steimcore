module Archivable
  extend ActiveSupport::Concern

  included do
    scope :archived,   -> { where.not(archived_at: nil) }
    scope :unarchived, -> { where(archived_at: nil) }
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def archived?
    archived_at.present?
  end
end
