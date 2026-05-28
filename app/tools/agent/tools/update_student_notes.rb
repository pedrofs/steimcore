module Agent
  module Tools
    # Surgical-edit tool for the agent's memory about this specific student
    # (`Student#notes_md`). The field stores training-plan rules that
    # should influence every future periodization/workout for this
    # student — NOT clinical content (anamnese), NOT structured demographic
    # fields, NOT one-off reminders or conversational chatter.
    class UpdateStudentNotes < RubyLLM::Tool
      description <<~DESC
        Edita a memória do agente sobre ESTE aluno (`notes_md`) por
        substituição cirúrgica: `old_string` (trecho exato a remover) e
        `new_string` (trecho que entra no lugar). Use somente para
        registrar regras de prescrição que devem influenciar toda
        periodização/treino futuro deste aluno — por exemplo, "manter
        sessões em até 50 min", "evitar exercícios de impacto no joelho",
        "preferir séries pesadas com poucas reps".

        Não use para conteúdo clínico/lesões (isso vai em `anamnesis_md`
        via `update_anamnesis`), nem para campos estruturados
        (`update_student`), nem para lembretes pontuais ou conversa
        ("avisar pra beber água amanhã" não é regra permanente).

        Regras de edição:
        - Memória vazia + `old_string` vazio → inicializa com `new_string`.
        - Memória com conteúdo + `old_string` vazio → erro.
        - `old_string` precisa aparecer exatamente uma vez na memória atual.
        - `new_string` pode ser vazio (remove o trecho).
      DESC

      param :old_string,
            type: :string,
            desc: "Trecho exato a substituir na memória atual. Deve aparecer uma única vez. Vazio só quando a memória está vazia (inicialização)."
      param :new_string,
            type: :string,
            desc: "Trecho que entra no lugar de `old_string`. Pode ser vazio para remover."
      param :summary_md,
            type: :string,
            desc: "Frase curta em pt-BR resumindo a alteração. Aparece como rótulo do card no chat."

      def name
        "update_student_notes"
      end

      def initialize(student:, trainer:)
        super()
        @student = student
        @trainer = trainer
      end

      def execute(old_string:, new_string:, summary_md:)
        summary_md = summary_md.to_s.strip
        return { error: "Faltou um resumo curto (`summary_md`) descrevendo a alteração." } if summary_md.empty?

        result = NotesEditor.apply(current: @student.notes_md, old_string: old_string, new_string: new_string)
        return { error: result.error } unless result.ok?

        @student.update!(notes_md: result.value)

        { ok: true, summary_md: summary_md }
      end
    end
  end
end
