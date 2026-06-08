# frozen_string_literal: true

class TrainingSessions::ClaimsController < InertiaController
  before_action :load_session

  def create
    @session.claim!(trainer: Current.user)
    redirect_back fallback_location: training_sessions_path
  end

  private
    def load_session
      @session = TrainingSession.joins(:student)
                                .where(students: { organization_id: current_organization.id })
                                .find(params[:training_session_id])
    end
end
