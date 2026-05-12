# frozen_string_literal: true

# Entry point for a workout-scoped voice edit. POST verifies the trainer can
# touch the targeted workout and redirects to the recorder, which is the same
# screen used elsewhere in the voice pipeline. The actual VoiceRecording row
# is created by Students::VoiceRecordingsController#create when the audio is
# uploaded; the kind and target_workout_id flow through the URL.
class PeriodizationVersions::Workouts::EditsController < InertiaController
  def create
    version = PeriodizationVersion.find(params[:periodization_version_id])
    workout = version.workouts.find(params[:workout_id])
    student = version.periodization.student

    raise ActiveRecord::RecordNotFound unless student.organization_id == current_organization.id

    redirect_to new_student_voice_recording_path(
      student,
      kind: "periodization_edit_workout",
      target_workout_id: workout.id,
      target_periodization_version_id: workout.periodization_version_id
    )
  end
end
