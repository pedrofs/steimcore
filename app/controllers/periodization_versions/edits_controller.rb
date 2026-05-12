# frozen_string_literal: true

# Entry point for a whole-periodization voice edit from the draft review page.
# Mirrors Periodizations::EditsController (which fires from the active page)
# but targets the draft version directly so the voice pipeline mutates the
# draft in place instead of forking a new one.
class PeriodizationVersions::EditsController < InertiaController
  def create
    version = PeriodizationVersion.find(params[:periodization_version_id])
    student = version.periodization.student

    raise ActiveRecord::RecordNotFound unless student.organization_id == current_organization.id

    redirect_to new_student_voice_recording_path(
      student,
      kind: "periodization_edit_periodization",
      target_periodization_version_id: version.id
    )
  end
end
