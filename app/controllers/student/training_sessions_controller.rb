class Student::TrainingSessionsController < Student::ApplicationController
  before_action :require_selected_profile
  before_action :load_session, only: :show
  rescue_from RuntimeError,                  with: :handle_ineligible
  rescue_from ActiveRecord::RecordNotUnique, with: :resume_active_session

  def create
    session = Current.student.start_training_session!
    redirect_to student_training_session_path(session)
  end

  def show
    render inertia: "student/training_sessions/show", props: {
      session: Student::LiveSessionView.new(@session).to_h
    }
  end

  private
    def load_session
      @session = Current.student.training_sessions.find(params[:id])
    end

    # Rest-day lockout and the start! eligibility guards both raise plain
    # RuntimeErrors with a Portuguese message; surface them as a flash on home.
    def handle_ineligible(exception)
      redirect_to student_home_path, alert: exception.message
    end

    # A double-tap / concurrent start trips the one-active-per-student unique
    # index. Rather than error, resolve to the single active session so the
    # student lands on the live screen they already own.
    def resume_active_session(_exception)
      session = Current.student.active_training_session
      if session
        redirect_to student_training_session_path(session)
      else
        redirect_to student_home_path
      end
    end
end
