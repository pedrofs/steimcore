# frozen_string_literal: true

# Review surface for a single PeriodizationVersion. While :generating, the page
# polls until the LLM finishes; while :completed and not yet promoted, the
# trainer can edit body_md and any workout's markdown, then promote (via
# Periodizations::PromotionsController) or discard (via #destroy). Only pending
# (status == :generating) or :failed versions can be discarded; promoted
# versions are immutable history.
class PeriodizationVersionsController < InertiaController
  before_action :load_version
  before_action :ensure_version_editable, only: :update
  before_action :ensure_version_destroyable, only: :destroy

  def show
    student = @version.periodization.student

    @title = "Revisar periodização — #{student.name}"
    add_breadcrumb(label: "Alunos", path: students_path)
    add_breadcrumb(label: student.name, path: student_path(student))
    add_breadcrumb(label: "Periodização", path: periodization_version_path(@version))

    render inertia: "periodization_versions/show", props: {
      version: version_props(@version),
      student: { id: student.id, name: student.name }
    }
  end

  def update
    @version.transaction do
      @version.update!(body_md: params[:body_md].to_s)
      Array(params[:workouts]).each do |attrs|
        workout = @version.workouts.find(attrs[:id])
        workout.update!(
          name: attrs[:name].to_s,
          content_md: attrs[:content_md].to_s
        )
      end
    end

    redirect_to periodization_version_path(@version), notice: "Alterações salvas."
  end

  def destroy
    periodization = @version.periodization
    student = periodization.student

    @version.transaction do
      @version.destroy!
      if periodization.versions.reload.empty?
        student.update!(active_periodization: nil) if student.active_periodization_id == periodization.id
        periodization.archive!
      end
    end

    redirect_to student_path(student), notice: "Versão descartada."
  end

  private
    def load_version
      @version = PeriodizationVersion.find(params[:id])
      organization_id = @version.periodization.student.organization_id
      raise ActiveRecord::RecordNotFound unless organization_id == current_organization.id
    end

    def ensure_version_editable
      if @version.promoted?
        redirect_to periodization_version_path(@version),
                    alert: "Esta versão já foi promovida e é imutável."
      elsif @version.status != "completed"
        redirect_to periodization_version_path(@version),
                    alert: "A geração ainda não terminou."
      end
    end

    def ensure_version_destroyable
      return unless @version.promoted?

      redirect_to periodization_version_path(@version),
                  alert: "Esta versão já foi promovida e não pode ser descartada."
    end

    def version_props(version)
      {
        id: version.id,
        status: version.status,
        body_md: version.body_md,
        error_message: version.error_message,
        promoted: version.promoted?,
        read_only: version.promoted? || version.superseded?,
        periodization_id: version.periodization_id,
        workouts: version.workouts.order(:position).map { |w|
          { id: w.id, name: w.name, position: w.position, content_md: w.content_md }
        }
      }
    end
end
