# frozen_string_literal: true

class TrainingSessions::BlockCompletionsController < InertiaController
  before_action :load_session
  rescue_from ArgumentError, with: :handle_invalid_index

  def create
    @session.mark_block_done!(params[:block_index].to_s)
    redirect_to training_sessions_path
  end

  def destroy
    @session.unmark_block!(params[:id].to_s)
    redirect_to training_sessions_path
  end

  private
    def load_session
      @session = TrainingSession.joins(:student)
                                .where(students: { organization_id: current_organization.id })
                                .find(params[:training_session_id])
    end

    def handle_invalid_index(exception)
      redirect_to training_sessions_path, alert: exception.message
    end
end
