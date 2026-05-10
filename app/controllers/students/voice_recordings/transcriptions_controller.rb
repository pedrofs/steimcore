# frozen_string_literal: true

# Retries a failed transcription on the same VoiceRecording. Sub-resource
# under the recording: a new "transcription attempt" is what we're creating,
# even though it lands back on the parent row.
class Students::VoiceRecordings::TranscriptionsController < InertiaController
  def create
    student = current_organization.students.find(params[:student_id])
    recording = student.voice_recordings.find(params[:voice_recording_id])

    if recording.status == "failed"
      recording.transition_to!(:transcribing)
      recording.update!(error_message: nil)
      TranscribeJob.perform_later(recording)
    end

    redirect_to student_voice_recording_path(student, recording)
  end
end
