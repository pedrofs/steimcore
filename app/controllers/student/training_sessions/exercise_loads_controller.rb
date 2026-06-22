class Student::TrainingSessions::ExerciseLoadsController < Student::ApplicationController
  before_action :require_selected_profile
  before_action :load_session
  before_action :ensure_exercise_present

  # A blank +value+ clears the movement's weight (records a clearance).
  def create
    @session.record_load!(exercise_name: exercise_name, value: load_value)
    # has_value distinguishes logging a weight from clearing one; the movement name
    # and value themselves are deliberately not tracked.
    track "load_recorded", training_session_id: @session.id, has_value: load_value.present?
    redirect_to student_training_session_path(@session)
  end

  private
    def load_session
      @session = Current.student.training_sessions.find(params[:training_session_id])
    end

    def exercise_name
      @exercise_name ||= params[:exercise_name].to_s.strip
    end

    def load_value
      @load_value ||= params[:value].to_s.strip
    end

    def ensure_exercise_present
      return if exercise_name.present?

      redirect_to student_training_session_path(@session), alert: "Exercício não informado."
    end
end
