class VoiceRecording < ApplicationRecord
  include JobStatusable

  KINDS = %w[anamnesis periodization_create periodization_edit_workout periodization_edit_periodization].freeze

  belongs_to :organization
  belongs_to :student
  belongs_to :trainer, class_name: "User"
  belongs_to :target_workout, class_name: "Workout", optional: true

  has_one_attached :audio

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :target_workout, presence: true, if: :workout_edit?

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
      when "periodization_create"
        version = student.start_periodization!(trainer: trainer, voice_recording: self)
        GeneratePeriodizationJob.perform_later(version.id)
      when "periodization_edit_workout"
        periodization = target_workout.periodization_version.periodization
        version = periodization.start_edit!(
          scope: :workout,
          trainer: trainer,
          voice_recording: self,
          target_workout: target_workout
        )
        GeneratePeriodizationJob.perform_later(version.id)
      when "periodization_edit_periodization"
        periodization = student.active_periodization
        raise "no active periodization to edit for student=#{student_id}" if periodization.nil?
        version = periodization.start_edit!(
          scope: :periodization,
          trainer: trainer,
          voice_recording: self
        )
        GeneratePeriodizationJob.perform_later(version.id)
      else
        raise "No post-transcript job for kind=#{kind.inspect}"
      end
    end

    def workout_edit?
      kind == "periodization_edit_workout"
    end
end
