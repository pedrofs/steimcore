# frozen_string_literal: true

# Promoting a version makes it the active version of its periodization. Only
# completed versions can be promoted (the LLM run produced a plan and the
# trainer reviewed it). The student-level active periodization pointer was
# already set when start_periodization! ran; promotion just sets
# periodization.current_version_id.
class PeriodizationVersions::PromotionsController < InertiaController
  before_action :load_version
  before_action :ensure_version_completed

  def create
    periodization = @version.periodization

    periodization.set_current_version!(@version)

    redirect_to student_periodization_path(periodization.student, periodization),
                notice: "Periodização salva."
  end

  private
    def load_version
      @version = PeriodizationVersion.find(params[:periodization_version_id])
      organization_id = @version.periodization.student.organization_id
      raise ActiveRecord::RecordNotFound unless organization_id == current_organization.id
    end

    def ensure_version_completed
      return if @version.status == "completed"

      redirect_to periodization_version_path(@version),
                  alert: "A geração ainda não terminou — não é possível salvar."
    end
end
