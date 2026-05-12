# frozen_string_literal: true

# Review surface for a single PeriodizationVersion. While :generating, the page
# polls until the LLM finishes; once :completed and not yet promoted, the
# trainer reviews the generated blocks-based plan and either promotes it (via
# PeriodizationVersions::PromotionsController) or discards it (via #destroy).
# Workout content is no longer editable from a textarea — all changes flow
# through the voice-edit pipeline. Promoted versions are immutable history.
class PeriodizationVersionsController < InertiaController
  before_action :load_version
  before_action :ensure_version_destroyable, only: :destroy

  def show
    student = @version.periodization.student

    @title = "Revisar periodização — #{student.name}"
    add_breadcrumb(label: "Alunos", path: students_path)
    add_breadcrumb(label: student.name, path: student_path(student))
    add_breadcrumb(label: "Periodização", path: periodization_version_path(@version))

    render inertia: "periodization_versions/show", props: {
      version: version_props(@version),
      voice_in_flight: voice_in_flight?(@version),
      student: { id: student.id, name: student.name }
    }
  end

  def destroy
    periodization = @version.periodization
    student = periodization.student

    @version.transaction do
      in_flight_recordings_targeting(@version).each(&:cancel!)
      VoiceRecording.where(target_periodization_version_id: @version.id)
                    .update_all(target_periodization_version_id: nil)
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

    def ensure_version_destroyable
      return unless @version.promoted?

      redirect_to periodization_version_path(@version),
                  alert: "Esta versão já foi promovida e não pode ser descartada."
    end

    IN_FLIGHT_STATUSES = %w[pending transcribing transcribed generating].freeze

    def in_flight_recordings_targeting(version)
      VoiceRecording.where(target_periodization_version_id: version.id, status: IN_FLIGHT_STATUSES)
    end

    def voice_in_flight?(version)
      in_flight_recordings_targeting(version).exists?
    end

    def version_props(version)
      {
        id: version.id,
        status: version.status,
        body_md: version.body_md,
        error_message: version.error_message,
        promoted: version.promoted?,
        read_only: version.read_only?,
        periodization_id: version.periodization_id,
        transcript: version.voice_recording&.transcript,
        workouts: version.workouts.order(:position).map { |w|
          { id: w.id, name: w.name, position: w.position, blocks: w.blocks }
        }
      }
    end
end
