# frozen_string_literal: true

# Entry point for "montar uma nova periodização" from the student profile.
# Seeds the chat with a trainer message stating the purpose (and the dose the
# current block is closing), enqueues the turn, and lands the trainer on the
# chat page with the agent's questions already streaming in.
class Students::AgentChats::PeriodizationBriefingsController < InertiaController
  before_action :load_student
  before_action :load_or_create_chat
  before_action :ensure_chat_idle

  def create
    @chat.brief_new_periodization!(trainer: Current.user)

    Agent::RunTurnJob.perform_later(@chat)

    redirect_to student_agent_chat_path(@student)
  end

  private
    def load_student
      @student = current_organization.students.find(params[:student_id])
    end

    def load_or_create_chat
      @chat = @student.find_or_create_agent_chat!
    end

    def ensure_chat_idle
      return if @chat.idle?

      redirect_to student_agent_chat_path(@student),
                  alert: "O assistente ainda está respondendo. Aguarde a resposta atual.",
                  status: :see_other
    end
end
