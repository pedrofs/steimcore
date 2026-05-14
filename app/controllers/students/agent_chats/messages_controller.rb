# frozen_string_literal: true

# Persists the trainer's message, flips the chat into `running`, and
# enqueues `Agent::RunTurnJob` to drive the turn out-of-band. Streaming and
# tool-boundary events reach the client via `Agent::ChatChannel`; on
# `turn_completed` the frontend partial-reloads to pick up canonical state.
class Students::AgentChats::MessagesController < InertiaController
  before_action :load_student
  before_action :load_chat
  before_action :ensure_chat_idle
  before_action :ensure_content_present

  def create
    @chat.transaction do
      @chat.messages.create!(role: :user, content: content_param, trainer: Current.user)
      @chat.update!(state: :running)
    end

    Agent::RunTurnJob.perform_later(@chat)

    redirect_to student_agent_chat_path(@student)
  end

  private
    def load_student
      @student = current_organization.students.find(params[:student_id])
    end

    def load_chat
      @chat = @student.agent_chat
      redirect_to student_agent_chat_path(@student) if @chat.nil?
    end

    def ensure_chat_idle
      return if @chat.idle?

      redirect_to student_agent_chat_path(@student),
                  alert: "O assistente ainda está respondendo. Aguarde a resposta atual.",
                  status: :see_other
    end

    def ensure_content_present
      return if content_param.present?

      redirect_to student_agent_chat_path(@student)
    end

    def content_param
      @content_param ||= params.dig(:message, :content).to_s.strip
    end
end
