# frozen_string_literal: true

# Seeds the conversation with a trainer message that states the purpose of the
# visit, so the agent opens the turn already knowing what is wanted instead of
# waiting on a blank chat. The briefing is a normal `role: :user` message —
# it shows up in the transcript exactly as written, phrased the way a trainer
# would phrase it.
module Agent::Chat::Briefable
  extend ActiveSupport::Concern

  # "Trainer wants a new periodization." Includes the current plan's dose and
  # how far through it the student is, so the agent can talk about the block
  # that is ending instead of asking about it. Returns the created message; the
  # caller enqueues the turn.
  def brief_new_periodization!(trainer:)
    transaction do
      message = messages.create!(role: :user, content: new_periodization_briefing, trainer: trainer)
      update!(state: :running)
      message
    end
  end

  private
    def new_periodization_briefing
      student = chattable

      if student.active_periodization.nil?
        <<~TEXT.strip
          Quero montar a primeira periodização para #{student.name}.

          Me faça as perguntas necessárias antes de propor o plano.
        TEXT
      else
        <<~TEXT.strip
          Quero montar uma nova periodização para #{student.name}, substituindo a atual.
          #{current_periodization_dose}
          Use a periodização atual como referência — o que faz sentido manter e o que
          já deu o que tinha que dar. Me faça as perguntas necessárias antes de propor
          o plano novo.
        TEXT
      end
    end

    # One line describing the block that is ending. Empty when the target is
    # undefined (no current version, or a version without a planned length) —
    # there is nothing truthful to say in that case.
    def current_periodization_dose
      progress = Student::PeriodizationProgress.new(chattable)
      return "" unless progress.applicable?

      weeks = chattable.active_periodization.current_version.periodization_length_weeks
      remaining = progress.sessions_remaining

      tail =
        if remaining.negative?
          "já passou #{sessions(-remaining)} do previsto"
        elsif remaining.zero?
          "a dose está fechada"
        else
          "faltam #{sessions(remaining)}"
        end

      "\nA atual é um bloco de #{weeks == 1 ? '1 semana' : "#{weeks} semanas"}: " \
      "#{progress.sessions_done} de #{progress.target} sessões concluídas, #{tail}.\n"
    end

    def sessions(count)
      count == 1 ? "1 sessão" : "#{count} sessões"
    end
end
