class Student::TrainingSessions::BlockCompletionsController < Student::ApplicationController
  before_action :require_selected_profile
  before_action :load_session
  rescue_from ArgumentError, with: :handle_invalid_index

  def create
    @session.mark_block_done!(params[:block_index].to_s)
    redirect_to student_training_session_path(@session)
  end

  def destroy
    @session.unmark_block!(params[:id].to_s)
    redirect_to student_training_session_path(@session)
  end

  private
    # Scoped to the selected profile's own sessions; toggling is allowed on
    # trainer-led sessions too (a student can track progress through a session
    # their trainer started).
    def load_session
      @session = Current.student.training_sessions.find(params[:training_session_id])
    end

    def handle_invalid_index(exception)
      redirect_to student_training_session_path(@session), alert: exception.message
    end
end
