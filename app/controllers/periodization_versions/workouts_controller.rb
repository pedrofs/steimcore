# frozen_string_literal: true

# Per-workout inline-edit endpoint. The trainer's `<WorkoutEditor>` PATCHes
# `{ workout: { blocks: [...] } }` and the action replaces the workout's
# blocks JSONB in place. Validation runs through the existing
# `Workout::Blocks.errors_for` so the pt-BR error strings are identical to
# what the LLM pipeline produces. Promoted/superseded versions are locked
# history and cannot be edited inline.
class PeriodizationVersions::WorkoutsController < InertiaController
  before_action :load_version_and_workout
  before_action :ensure_version_editable

  def update
    if @workout.update(workout_params)
      redirect_to periodization_version_path(@version), notice: "Treino atualizado."
    else
      redirect_to periodization_version_path(@version),
                  inertia: { errors: @workout.errors.to_hash(true) }
    end
  end

  private
    def load_version_and_workout
      @version = PeriodizationVersion.find(params[:periodization_version_id])
      organization_id = @version.periodization.student.organization_id
      raise ActiveRecord::RecordNotFound unless organization_id == current_organization.id

      @workout = @version.workouts.find(params[:id])
    end

    def ensure_version_editable
      return unless @version.read_only?

      redirect_to periodization_version_path(@version),
                  alert: "Esta versão não pode ser editada."
    end

    def workout_params
      params.require(:workout).permit(blocks: [
        :kind, :name, :prescription, :rest_s, :notes, :text_md, :label, :rounds,
        { items: [ :name, :prescription, :notes ] }
      ])
    end
end
