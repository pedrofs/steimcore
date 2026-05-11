# Dismiss a failed VoiceRecording: marks the row dismissed (so the inbox stops
# surfacing it) and, when dismissing a periodization_create whose periodization
# has no other completed versions, archives that orphan periodization in the
# same transaction. Periodization edits never touch the parent — only the
# failed version stays attached as history.
module VoiceRecording::Dismissable
  extend ActiveSupport::Concern

  def dismiss!
    return unless status == "failed"

    transaction do
      update!(dismissed_at: Time.current)
      archive_orphan_periodization_if_applicable
    end
  end

  private
    def archive_orphan_periodization_if_applicable
      return unless kind == "periodization_create"

      periodization = periodization_version&.periodization
      return if periodization.nil?
      return if periodization.versions.where(status: "completed").exists?

      periodization.archive!
    end
end
