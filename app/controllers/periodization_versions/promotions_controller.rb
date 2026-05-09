# frozen_string_literal: true

# Promoting a version makes it the active version of its periodization. Only
# completed versions can be promoted (the LLM run produced a plan and the
# trainer reviewed it). The student-level active periodization pointer was
# already set when start_periodization! ran; promotion just sets
# periodization.current_version_id.
class PeriodizationVersions::PromotionsController < InertiaController
  def create
    version = PeriodizationVersion.find(params[:periodization_version_id])
    periodization = version.periodization
    student = periodization.student

    raise ActiveRecord::RecordNotFound unless student.organization_id == current_organization.id

    if version.status != "completed"
      redirect_to periodization_version_path(version),
                  alert: "A geração ainda não terminou — não é possível salvar."
      return
    end

    periodization.set_current_version!(version)

    redirect_to student_periodization_path(student, periodization),
                notice: "Periodização salva."
  end
end
