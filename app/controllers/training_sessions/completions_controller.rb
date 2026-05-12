# frozen_string_literal: true

class TrainingSessions::CompletionsController < InertiaController
  before_action :load_session

  def create
    @session.finish!
    redirect_to training_sessions_path
  end

  def destroy
    @session.reopen!
    redirect_to training_sessions_path
  end

  private
    def load_session
      @session = Current.user.training_sessions.find(params[:training_session_id])
    end
end
