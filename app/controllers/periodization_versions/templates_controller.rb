# frozen_string_literal: true

# "Salvar como modelo" — snapshots a completed version's content into a new
# org-scoped PeriodizationTemplate. The noun produced is a template, so this is
# its own sub-resource (CLAUDE.md: RESTful-only, no verb actions). Org-guarded
# through the version's student so a trainer cannot templatize another org's
# version. Only a completed version can be saved — that is the surface where the
# trainer views the plan's content and decides it is good.
class PeriodizationVersions::TemplatesController < InertiaController
  before_action :load_version
  before_action :ensure_version_completed

  def create
    PeriodizationTemplate.create_from_version!(
      @version,
      name: template_params[:name].to_s.strip,
      description: template_params[:description].presence
    )

    redirect_to periodization_version_path(@version), notice: "Modelo salvo."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to periodization_version_path(@version),
                inertia: { errors: error.record.errors.to_hash(true) }
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
                  alert: "Só é possível salvar como modelo uma periodização concluída."
    end

    def template_params
      params.require(:periodization_template).permit(:name, :description)
    end
end
