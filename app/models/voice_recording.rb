class VoiceRecording < ApplicationRecord
  include JobStatusable
  include Transcribable
  include AnamnesisRegeneratable
  include Retryable
  include Dismissable
  include Cancellable

  KINDS = %w[anamnesis periodization_create periodization_edit_workout periodization_edit_periodization].freeze

  AUDIO_RETENTION = 7.days

  belongs_to :organization
  belongs_to :student
  belongs_to :trainer, class_name: "User"
  belongs_to :target_workout, class_name: "Workout", optional: true
  belongs_to :target_periodization_version, class_name: "PeriodizationVersion", optional: true

  has_one :periodization_version, dependent: :nullify

  has_one_attached :audio

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :target_workout, presence: true, if: :workout_edit?

  job_statuses transitions: {
    pending:      %i[transcribing failed cancelled],
    transcribing: %i[transcribed failed cancelled],
    transcribed:  %i[generating failed cancelled],
    generating:   %i[completed failed cancelled],
    completed:    [],
    failed:       %i[pending transcribing generating],
    cancelled:    []
  }

  after_initialize :set_default_status, if: :new_record?

  def fail!(message)
    self.error_message = message
    transition_to!(:failed)
  end

  def self.purge_audio_older_than(duration)
    cutoff = duration.ago
    joins(:audio_attachment)
      .where("voice_recordings.created_at < ?", cutoff)
      .find_each { |recording| recording.audio.purge_later }
  end

  private
    def set_default_status
      self.status ||= "pending"
    end

    # Auto-confirm the transcript and dispatch the kind-appropriate generation
    # job. Called by Transcribable#transcribe! once Whisper finishes; not part
    # of the public surface.
    def confirm_transcript!
      transaction do
        transition_to!(:generating)
        enqueue_post_transcript_job!
      end
      self
    end

    def enqueue_post_transcript_job!
      case kind
      when "anamnesis"
        RegenerateAnamnesisJob.perform_later(self)
      when "periodization_create"
        version = student.start_periodization!(trainer: trainer, voice_recording: self)
        GeneratePeriodizationJob.perform_later(version)
      when "periodization_edit_workout"
        enqueue_periodization_edit_job!(scope: :workout, target_workout: target_workout)
      when "periodization_edit_periodization"
        enqueue_periodization_edit_job!(scope: :periodization)
      else
        raise "No post-transcript job for kind=#{kind.inspect}"
      end
    end

    def enqueue_periodization_edit_job!(scope:, target_workout: nil)
      target_version = resolve_target_version(scope: scope, target_workout: target_workout)
      raise "no target periodization version for recording=#{id}" if target_version.nil?

      if target_version.read_only?
        version = target_version.periodization.start_edit!(
          scope: scope,
          trainer: trainer,
          voice_recording: self,
          target_workout: target_workout
        )
        GeneratePeriodizationJob.perform_later(version)
      else
        target_version.update!(voice_recording: self)
        target_version.transition_to!(:generating)
        GeneratePeriodizationJob.perform_later(target_version)
      end
    end

    def resolve_target_version(scope:, target_workout:)
      return target_periodization_version if target_periodization_version.present?
      return target_workout&.periodization_version if scope == :workout
      student.active_periodization&.current_version
    end

    def workout_edit?
      kind == "periodization_edit_workout"
    end
end
