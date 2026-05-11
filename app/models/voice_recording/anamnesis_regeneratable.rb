# Claude boundary for anamnesis regeneration owned by the recording. Builds a
# pt-BR prompt that carries forward the prior anamnesis_md plus the student's
# structured fields, adds the new (trainer-confirmed) transcript, and asks
# Claude to produce the refreshed full markdown. The result lands on
# `proposed_anamnesis_md` and the recording transitions to :completed. The
# student record is NOT touched here — the trainer reviews
# `proposed_anamnesis_md` and explicitly commits.
module VoiceRecording::AnamnesisRegeneratable
  extend ActiveSupport::Concern

  ANAMNESIS_MODEL = "claude-opus-4-7"

  def regenerate_anamnesis!
    return unless status == "generating"

    response = RubyLLM
      .chat(model: ANAMNESIS_MODEL)
      .with_instructions(anamnesis_system_prompt)
      .ask(anamnesis_user_prompt)

    update!(proposed_anamnesis_md: response.content.to_s)
    transition_to!(:completed)
  rescue StandardError => e
    fail!(e.message.presence || e.class.name)
    raise if Rails.env.test? && ENV["RAISE_JOB_ERRORS"] == "true"
  end

  private
    def anamnesis_system_prompt
      <<~PROMPT
        Você é um assistente de um personal trainer numa academia de musculação.
        Sua tarefa é manter a anamnese de um aluno como um documento markdown
        coerente em português do Brasil. A cada nova fala do treinador, você
        recebe a anamnese atual e a transcrição da nova fala, e deve devolver a
        anamnese completa atualizada — não apenas as mudanças. Preserve
        informações antigas que continuam relevantes; substitua o que foi
        corrigido; integre o que é novo. Use seções markdown claras (Histórico,
        Restrições, Objetivos, Observações). Não inicie o documento com um
        título de nível 1 (ex.: "# Anamnese — <nome>") — comece direto pela
        primeira seção de nível 2 (##). Não invente dados que o treinador
        não tenha mencionado. Não mencione que você é uma IA.
      PROMPT
    end

    def anamnesis_user_prompt
      <<~PROMPT
        ## Aluno
        Nome: #{student.name}
        Idade: #{student.age || "(não informada)"}
        Sexo: #{student.sex || "(não informado)"}
        Objetivo principal: #{student.primary_goal || "(não informado)"}
        Frequência semanal: #{student.weekly_frequency || "(não informada)"}
        Restrições resumidas: #{student.restrictions_summary.presence || "(nenhuma)"}

        ## Anamnese atual
        #{student.anamnesis_md.presence || "(vazia — primeira gravação)"}

        ## Nova fala do treinador (transcrita)
        #{transcript}

        ## Tarefa
        Devolva a anamnese completa atualizada em markdown, integrando a nova
        fala. Apenas o markdown, sem comentários extras.
      PROMPT
    end
end
