# frozen_string_literal: true

class Students::VoiceRecordings::TranscriptConfirmationsController < InertiaController
  def create
    student = current_organization.students.find(params[:student_id])
    recording = student.voice_recordings.find(params[:voice_recording_id])

    text = params[:transcript].to_s

    if text.strip.empty?
      redirect_to student_voice_recording_path(student, recording),
                  alert: "A transcrição não pode ficar em branco."
      return
    end

    recording.confirm_transcript!(text)

    case recording.kind
    when "periodization_create", "periodization_edit_workout"
      version = PeriodizationVersion.find_by!(voice_recording_id: recording.id)
      redirect_to periodization_version_path(version)
    else
      redirect_to student_voice_recording_path(student, recording)
    end
  end
end
