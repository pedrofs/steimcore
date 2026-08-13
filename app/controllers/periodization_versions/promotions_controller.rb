# frozen_string_literal: true

# Promoting a version makes it the active version of its periodization. Only
# completed versions can be promoted (the LLM run produced a plan and the
# trainer reviewed it). The student-level active periodization pointer was
# already set when start_periodization! ran; promotion just sets
# periodization.current_version_id.
class PeriodizationVersions::PromotionsController < InertiaController
  before_action :load_version
  before_action :ensure_periodization_active
  before_action :ensure_version_completed

  def create
    periodization = @version.periodization

    periodization.set_current_version!(@version)

    redirect_to safe_return_to || student_periodization_path(periodization.student, periodization),
                notice: "Periodização salva."
  end

  private
    def load_version
      @version = PeriodizationVersion.find(params[:periodization_version_id])
      organization_id = @version.periodization.student.organization_id
      raise ActiveRecord::RecordNotFound unless organization_id == current_organization.id
    end

    # An archived block is frozen: promoting a draft left over from before the
    # student moved on would rewrite the split they actually trained.
    def ensure_periodization_active
      return unless @version.periodization.archived?

      redirect_to periodization_version_path(@version),
                  alert: "Esta periodização está arquivada e não pode ser alterada."
    end

    def ensure_version_completed
      return if @version.status == "completed"

      redirect_to periodization_version_path(@version),
                  alert: "A geração ainda não terminou — não é possível salvar."
    end
end
