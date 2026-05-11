# frozen_string_literal: true

# Retries a failed VoiceRecording. The recording itself picks the right resume
# point (re-transcribe vs. re-generate) based on transcript presence and kind;
# this controller is just the HTTP boundary.
class Students::VoiceRecordings::RetriesController < InertiaController
  before_action :load_student_and_recording

  def create
    @recording.retry!

    redirect_to student_voice_recording_path(@student, @recording)
  end

  private
    def load_student_and_recording
      @student = current_organization.students.find(params[:student_id])
      @recording = @student.voice_recordings.find(params[:voice_recording_id])
    end
end
