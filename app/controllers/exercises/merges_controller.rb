# frozen_string_literal: true

# Consolidation in the Exercises admin (PRD #163): merging a duplicate Exercise
# into a surviving one. Creating a merge repoints the loser's Aliases onto the
# target and records `merged_into`; afterwards every name that resolved to the
# loser resolves to the survivor. Modeled as a sub-resource of an Exercise rather
# than a custom verb on ExercisesController (project RESTful-controller convention).
class Exercises::MergesController < InertiaController
  before_action :load_exercise
  before_action :load_target
  before_action :ensure_distinct

  def create
    @exercise.merge_into!(@target)

    redirect_to exercise_path(@target),
                notice: "#{@exercise.name} consolidado em #{@target.name}."
  end

  private
    def load_exercise
      @exercise = catalog.find(params[:exercise_id])
    end

    def load_target
      @target = catalog.find_by(id: params[:target_id])
      return if @target

      redirect_to exercise_path(@exercise), alert: "Selecione um exercício de destino válido."
    end

    def ensure_distinct
      return unless @target == @exercise

      redirect_to exercise_path(@exercise), alert: "Não é possível consolidar um exercício nele mesmo."
    end

    # Merged-away Exercises are hidden from the admin and can be neither the loser
    # nor the target of a merge.
    def catalog
      Exercise.where(merged_into_id: nil)
    end
end
