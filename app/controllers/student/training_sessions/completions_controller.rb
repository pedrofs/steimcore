class Student::TrainingSessions::CompletionsController < Student::ApplicationController
  before_action :require_selected_profile
  before_action :load_session

  # Finishing stamps finished_at so the session counts toward progress and the
  # frequency calendar. Allowed on trainer-led sessions too — a student can
  # close out a session their trainer started. Lands back on home so the
  # "trained today" celebration shows.
  def create
    @session.finish!
    redirect_to student_home_path
  end

  private
    def load_session
      @session = Current.student.training_sessions.find(params[:training_session_id])
    end
end
