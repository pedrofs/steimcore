# frozen_string_literal: true

# Inline-edit entry from the active periodization page. Forks a byte-identical
# clone of the promoted version into a fresh draft (no LLM) and redirects the
# trainer to the new version's review page, where the inline editor lives.
class Periodizations::InlineEditsController < InertiaController
  before_action :load_periodization
  before_action :ensure_current_version_present

  def create
    new_version = @periodization.versions.build(
      trainer: Current.user,
      parent_version: @periodization.current_version
    )
    new_version.fork_with!(scope: :clone, patch: nil, trainer: Current.user)

    redirect_to periodization_version_path(new_version)
  end

  private
    def load_periodization
      @periodization = Periodization.find(params[:periodization_id])
      organization_id = @periodization.student.organization_id
      raise ActiveRecord::RecordNotFound unless organization_id == current_organization.id
    end

    def ensure_current_version_present
      return if @periodization.current_version_id.present?

      redirect_to student_periodization_path(@periodization.student, @periodization),
                  alert: "Esta periodização não tem uma versão atual para editar."
    end
end
