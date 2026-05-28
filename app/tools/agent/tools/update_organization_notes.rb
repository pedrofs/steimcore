module Agent
  module Tools
    # Surgical-edit tool for the agent's memory about the organization
    # (`Organization#notes_md`). The field stores training-plan rules that
    # should influence every periodization/workout generated for ANY
    # student in the gym — NOT trainer scheduling preferences, NOT gym
    # ops, NOT billing. Because this affects every future conversation,
    # the agent should confirm with the trainer before writing here unless
    # the trainer asked explicitly.
    class UpdateOrganizationNotes < RubyLLM::Tool
      description <<~DESC
        Edita a memória do agente sobre a ORGANIZAÇÃO (`notes_md`) por
        substituição cirúrgica: `old_string` (trecho exato a remover) e
        `new_string` (trecho que entra no lugar). Use somente para
        registrar regras de prescrição que valem para TODOS os alunos da
        academia — por exemplo, "sempre terminar com alongamentos",
        "sessões de no máximo 1 hora", "preferir RPE em vez de %1RM",
        "incluir aquecimento livre de 5 a 10 min".

        Como essas regras afetam toda periodização/treino futuro de
        qualquer aluno, **confirme com o treinador antes de gravar**
        quando a intenção não estiver explícita. Não use para preferências
        operacionais (agenda, contato, mensalidade) nem para coisas que
        valem só para um aluno específico (isso vai em
        `update_student_notes`).

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
        "update_organization_notes"
      end

      def initialize(organization:, trainer:)
        super()
        @organization = organization
        @trainer      = trainer
      end

      def execute(old_string:, new_string:, summary_md:)
        summary_md = summary_md.to_s.strip
        return { error: "Faltou um resumo curto (`summary_md`) descrevendo a alteração." } if summary_md.empty?

        result = NotesEditor.apply(current: @organization.notes_md, old_string: old_string, new_string: new_string)
        return { error: result.error } unless result.ok?

        @organization.update!(notes_md: result.value)

        { ok: true, summary_md: summary_md }
      end
    end
  end
end
