# frozen_string_literal: true

# Dismisses a failed VoiceRecording from the inbox without retrying. The
# model's `dismiss!` is a no-op for non-failed rows, so this controller stays
# as thin HTTP plumbing.
class Students::VoiceRecordings::DismissalsController < InertiaController
  before_action :load_student_and_recording

  def create
    @recording.dismiss!

    redirect_to inbox_path
  end

  private
    def load_student_and_recording
      @student = current_organization.students.find(params[:student_id])
      @recording = @student.voice_recordings.find(params[:voice_recording_id])
    end
end
