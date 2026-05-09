# frozen_string_literal: true

# Entry point for a periodization-scoped voice edit. POST verifies the trainer
# can touch the periodization and redirects to the recorder, which is the same
# screen used elsewhere in the voice pipeline. The actual VoiceRecording row
# is created by Students::VoiceRecordingsController#create when the audio is
# uploaded; the kind flows through the URL.
class Periodizations::EditsController < InertiaController
  def create
    periodization = Periodization.find(params[:periodization_id])
    student = periodization.student

    raise ActiveRecord::RecordNotFound unless student.organization_id == current_organization.id

    redirect_to new_student_voice_recording_path(
      student,
      kind: "periodization_edit_periodization"
    )
  end
end
