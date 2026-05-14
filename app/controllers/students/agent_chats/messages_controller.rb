# frozen_string_literal: true

# Synchronous turn endpoint for the per-student chat. Persists the trainer's
# message, gates concurrent turns via the chat's `state`, runs the agent
# in-process (no job, no streaming), and redirects back to the chat page.
# Streaming and the background job move in via #67.
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

    begin
      StudentAgent.new(chat: @chat, student: @student, trainer: Current.user).complete
    ensure
      @chat.update!(state: :idle)
    end

    redirect_to student_agent_chat_path(@student)
  rescue StandardError => e
    @chat.update!(state: :idle) if @chat&.persisted?
    Rails.logger.error("Agent turn failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(20)&.join("\n")}")
    redirect_to student_agent_chat_path(@student),
                alert: "O assistente falhou ao responder. Tente novamente."
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
                  alert: "O assistente ainda está respondendo. Aguarde a resposta atual."
    end

    def ensure_content_present
      return if content_param.present?

      redirect_to student_agent_chat_path(@student)
    end

    def content_param
      @content_param ||= params.dig(:message, :content).to_s.strip
    end
end
