# frozen_string_literal: true

class TrainingSessions::WorkoutSwapsController < InertiaController
  before_action :load_session
  before_action :load_target_workout
  rescue_from ArgumentError, with: :handle_invalid_swap

  def create
    @session.swap_workout!(@target_workout)
    redirect_to training_sessions_path
  end

  private
    def load_session
      @session = Current.user.training_sessions.find(params[:training_session_id])
    end

    def load_target_workout
      @target_workout = Workout.find(params[:workout_id])
    end

    def handle_invalid_swap(exception)
      redirect_to training_sessions_path, alert: exception.message
    end
end
