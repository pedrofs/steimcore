# frozen_string_literal: true

class Students::VoiceRecordings::TranscriptConfirmationsController < InertiaController
  before_action :load_student_and_recording
  before_action :ensure_transcript_present

  def create
    @recording.confirm_transcript!(transcript_text)

    case @recording.kind
    when "periodization_create", "periodization_edit_workout", "periodization_edit_periodization"
      version = PeriodizationVersion.find_by!(voice_recording_id: @recording.id)
      redirect_to periodization_version_path(version)
    else
      redirect_to student_voice_recording_path(@student, @recording)
    end
  end

  private
    def load_student_and_recording
      @student = current_organization.students.find(params[:student_id])
      @recording = @student.voice_recordings.find(params[:voice_recording_id])
    end

    def transcript_text
      @transcript_text ||= params[:transcript].to_s
    end

    def ensure_transcript_present
      return unless transcript_text.strip.empty?

      redirect_to student_voice_recording_path(@student, @recording),
                  alert: "A transcrição não pode ficar em branco."
    end
end
