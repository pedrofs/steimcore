class PeriodizationVersion < ApplicationRecord
  include JobStatusable
  include Forkable
  include Generatable

  belongs_to :periodization
  belongs_to :trainer, class_name: "User"
  belongs_to :voice_recording, optional: true
  belongs_to :parent_version, class_name: "PeriodizationVersion", optional: true

  has_many :workouts, dependent: :destroy

  job_statuses transitions: {
    pending:    %i[generating failed],
    generating: %i[completed failed],
    completed:  %i[generating],
    failed:     %i[generating]
  }

  after_initialize :set_default_status, if: :new_record?

  # Terminal transitions bubble up to the owning voice_recording so that
  # VoiceRecording#status is the single source of truth for end-to-end
  # pipeline state. The recording is expected to be in :generating at this
  # point (the production pipeline walks it there before generation begins);
  # tests that fixture versions in non-pipeline states use a nil
  # voice_recording.

  def complete!
    transaction do
      transition_to!(:completed)
      voice_recording.transition_to!(:completed) if voice_recording.present?
    end
  end

  def fail!(message)
    self.error_message = message
    transaction do
      transition_to!(:failed)
      voice_recording.fail!(message) if voice_recording.present? && voice_recording.status != "failed"
    end
  end

  def promoted?
    periodization.current_version_id == id
  end

  # A version is "superseded" when another version was forked from it. In the
  # edit flow, start_edit! sets parent_version on the new version to the prior
  # current_version, so the prior current_version develops descendants the
  # moment a successor is created. We use this as the signal that this version
  # is locked-in history rather than an in-review draft.
  def superseded?
    PeriodizationVersion.where(parent_version_id: id).exists?
  end

  # A version is read-only when it is no longer the working draft — either it
  # has been promoted, or it has been superseded by a child fork. The voice
  # pipeline uses this to decide between forking a new version (read-only
  # target) and mutating the draft in place (editable target).
  def read_only?
    promoted? || superseded?
  end

  private
    def set_default_status
      self.status ||= "pending"
    end
end
