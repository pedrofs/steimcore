# frozen_string_literal: true

# Per-workout inline-edit endpoint for a template's workouts. The trainer's
# `<WorkoutEditor>` PATCHes `{ workout: { blocks: [...] } }` and the action
# replaces the workout's blocks JSONB in place. Parallel to
# `PeriodizationVersions::WorkoutsController#update` — same contract, same
# `permit` shape, and validation runs through the shared `Blockable`/`Blocks`
# path so the pt-BR error strings are byte-identical across both editors.
# Templates mutate in place with no version locking (ADR-0008): there is no
# read-only history to guard, so a template workout is always editable.
class PeriodizationTemplates::WorkoutsController < InertiaController
  before_action :load_template_and_workout

  def update
    destination = safe_return_to || edit_periodization_template_path(@template)

    if @workout.update(workout_params)
      redirect_to destination, notice: "Treino atualizado."
    else
      redirect_to destination, inertia: { errors: @workout.errors.to_hash(true) }
    end
  end

  private
    def load_template_and_workout
      @template = current_organization.periodization_templates.find(params[:periodization_template_id])
      @workout = @template.workouts.find(params[:id])
    end

    def workout_params
      params.require(:workout).permit(blocks: [
        :kind, :name, :prescription, :rest_s, :notes, :text_md, :label, :rounds,
        { items: [ :name, :prescription, :notes ] }
      ])
    end
end
