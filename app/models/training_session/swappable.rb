module TrainingSession::Swappable
  extend ActiveSupport::Concern

  def swap_workout!(new_workout)
    raise ArgumentError, "treino alvo é obrigatório" if new_workout.nil?
    raise ArgumentError, "treino alvo não pertence à periodização da sessão" unless eligible_swap_target?(new_workout)

    transaction do
      update!(
        workout: new_workout,
        workout_name_snapshot: new_workout.name,
        workout_position_snapshot: new_workout.position,
        blocks_snapshot: new_workout.blocks,
        progress: []
      )
    end
  end

  def eligible_swap_workouts
    version = current_swap_version
    return Workout.none if version.nil?
    version.workouts.order(:position)
  end

  private
    def eligible_swap_target?(target_workout)
      version = current_swap_version
      return false if version.nil?
      target_workout.periodization_version_id == version.id
    end

    def current_swap_version
      if workout_id.present? && workout&.periodization_version
        workout.periodization_version
      else
        student.active_periodization&.current_version
      end
    end
end
