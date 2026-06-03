# frozen_string_literal: true

class TrainingSessions::ExerciseLoadsController < InertiaController
  before_action :load_session
  before_action :ensure_exercise_present

  # A blank +value+ clears the movement's weight (records a clearance).
  def create
    @session.record_load!(exercise_name: exercise_name, value: load_value)
    redirect_back fallback_location: training_sessions_path
  end

  private
    def load_session
      @session = TrainingSession.joins(:student)
                                .where(students: { organization_id: current_organization.id })
                                .find(params[:training_session_id])
    end

    def exercise_name
      @exercise_name ||= params[:exercise_name].to_s.strip
    end

    def load_value
      @load_value ||= params[:value].to_s.strip
    end

    def ensure_exercise_present
      return if exercise_name.present?

      redirect_back fallback_location: training_sessions_path, alert: "Exercício não informado."
    end
end
