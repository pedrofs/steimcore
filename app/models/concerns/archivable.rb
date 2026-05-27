module Archivable
  extend ActiveSupport::Concern

  included do
    scope :archived,   -> { where.not(archived_at: nil) }
    scope :unarchived, -> { where(archived_at: nil) }
  end

  def archive!(reason: nil)
    attributes = { archived_at: Time.current }
    attributes[:archive_reason] = reason.presence if has_attribute?(:archive_reason)
    update!(attributes)
  end

  def restore!
    attributes = { archived_at: nil }
    attributes[:archive_reason] = nil if has_attribute?(:archive_reason)
    update!(attributes)
  end

  def archived?
    archived_at.present?
  end
end
