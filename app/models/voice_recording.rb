class VoiceRecording < ApplicationRecord
  include JobStatusable

  KINDS = %w[anamnesis].freeze

  belongs_to :organization
  belongs_to :student
  belongs_to :trainer, class_name: "User"

  has_one_attached :audio

  validates :kind, presence: true, inclusion: { in: KINDS }

  job_statuses transitions: {
    pending:      %i[transcribing failed],
    transcribing: %i[transcribed failed],
    transcribed:  %i[generating failed],
    generating:   %i[completed failed],
    completed:    [],
    failed:       %i[transcribing]
  }

  after_initialize :set_default_status, if: :new_record?

  # Persist the trainer-edited transcript and dispatch the next job in the
  # pipeline. The dispatched job is determined by `kind`.
  def confirm_transcript!(text)
    transaction do
      update!(transcript: text, transcript_edited_at: Time.current)
      transition_to!(:generating)
      enqueue_post_transcript_job!
    end
    self
  end

  def fail!(message)
    self.error_message = message
    transition_to!(:failed)
  end

  private
    def set_default_status
      self.status ||= "pending"
    end

    def enqueue_post_transcript_job!
      case kind
      when "anamnesis"
        RegenerateAnamnesisJob.perform_later(id)
      else
        raise "No post-transcript job for kind=#{kind.inspect}"
      end
    end
end
