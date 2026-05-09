# Claude boundary for anamnesis regeneration. Builds a pt-BR prompt that
# carries forward the prior anamnesis_md plus the student's structured fields,
# adds the new (trainer-confirmed) transcript, and asks Claude to produce the
# refreshed full markdown. Result lands on `proposed_anamnesis_md` and the
# recording transitions to :completed. The student record is NOT touched here
# — the trainer reviews `proposed_anamnesis_md` and explicitly commits.
class RegenerateAnamnesisJob < ApplicationJob
  queue_as :default

  MODEL = "claude-sonnet-4-5"

  def perform(voice_recording_id)
    recording = VoiceRecording.find(voice_recording_id)
    return unless recording.status == "generating"

    student = recording.student

    response = RubyLLM.chat(model: MODEL).with_instructions(system_prompt).ask(user_prompt(student, recording.transcript))
    proposed = response.content.to_s

    recording.update!(proposed_anamnesis_md: proposed)
    recording.transition_to!(:completed)
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    recording&.fail!(e.message.presence || e.class.name)
    raise if Rails.env.test? && ENV["RAISE_JOB_ERRORS"] == "true"
  end

  private
    def system_prompt
      <<~PROMPT
        Você é um assistente de um personal trainer numa academia de musculação.
        Sua tarefa é manter a anamnese de um aluno como um documento markdown
        coerente em português do Brasil. A cada nova fala do treinador, você
        recebe a anamnese atual e a transcrição da nova fala, e deve devolver a
        anamnese completa atualizada — não apenas as mudanças. Preserve
        informações antigas que continuam relevantes; substitua o que foi
        corrigido; integre o que é novo. Use seções markdown claras (Histórico,
        Restrições, Objetivos, Observações). Não invente dados que o treinador
        não tenha mencionado. Não mencione que você é uma IA.
      PROMPT
    end

    def user_prompt(student, transcript)
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
