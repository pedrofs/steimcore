# frozen_string_literal: true

# Persists the trainer's message, flips the chat into `running`, and
# enqueues `Agent::RunTurnJob` to drive the turn out-of-band. Streaming and
# tool-boundary events reach the client via `Agent::ChatChannel`; on
# `turn_completed` the frontend partial-reloads to pick up canonical state.
class Students::AgentChats::MessagesController < InertiaController
  MAX_ATTACHMENT_COUNT = 5
  MAX_ATTACHMENT_BYTES = 20.megabytes

  before_action :load_student
  before_action :load_chat
  before_action :ensure_chat_idle
  before_action :ensure_content_or_attachments_present
  before_action :ensure_attachment_count_within_limit
  before_action :ensure_attachment_sizes_within_limit

  def create
    @chat.transaction do
      message = @chat.messages.create!(role: :user, content: content_param, trainer: Current.user)
      message.attachments.attach(attachment_files) if attachment_files.any?
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

    def ensure_content_or_attachments_present
      return if content_param.present? || attachment_files.any?

      redirect_to student_agent_chat_path(@student)
    end

    def ensure_attachment_count_within_limit
      return if attachment_files.size <= MAX_ATTACHMENT_COUNT

      redirect_to student_agent_chat_path(@student),
                  alert: "Você pode anexar no máximo #{MAX_ATTACHMENT_COUNT} arquivos por mensagem."
    end

    def ensure_attachment_sizes_within_limit
      oversize = attachment_files.find { |f| f.respond_to?(:size) && f.size > MAX_ATTACHMENT_BYTES }
      return if oversize.nil?

      name = oversize.respond_to?(:original_filename) ? oversize.original_filename : "Arquivo"
      redirect_to student_agent_chat_path(@student),
                  alert: "Arquivo \"#{name}\" excede o limite de 20 MB."
    end

    def content_param
      @content_param ||= params.dig(:message, :content).to_s.strip
    end

    def attachment_files
      @attachment_files ||= Array(params.dig(:message, :attachments)).reject(&:blank?)
    end
end
