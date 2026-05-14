module Agent
  module Tools
    # Auto-commits a new anamnese markdown to the student. There is no
    # separate proposed/commit review step — the chat transcript itself is
    # the audit trail.
    #
    # The agent writes a short pt-BR `summary_md` describing what changed
    # and the chat card surfaces that sentence verbatim.
    class UpdateAnamnesis < RubyLLM::Tool
      description <<~DESC
        Atualiza a anamnese do aluno (campo `anamnesis_md`). Substitui o conteúdo
        atual por inteiro pelo novo markdown fornecido. Use para registrar
        objetivos, restrições, lesões, histórico, preferências, ou qualquer
        outra informação que o treinador deva levar em conta nos próximos
        treinos. A mudança entra em vigor imediatamente.
      DESC

      param :anamnesis_md,
            type: :string,
            desc: "Conteúdo completo da nova anamnese em markdown (pt-BR). Substitui o conteúdo atual por inteiro."
      param :summary_md,
            type: :string,
            desc: "Uma frase curta em pt-BR resumindo o que mudou. Exibida ao treinador como rótulo do card no chat."

      def name
        "update_anamnesis"
      end

      def initialize(student:, trainer:)
        super()
        @student = student
        @trainer = trainer
      end

      def execute(anamnesis_md:, summary_md:)
        anamnesis_md = anamnesis_md.to_s
        summary_md   = summary_md.to_s.strip

        return { error: "A anamnese não pode ficar em branco." } if anamnesis_md.strip.empty?
        return { error: "Faltou um resumo curto (`summary_md`) descrevendo a alteração." } if summary_md.empty?

        @student.update!(anamnesis_md: anamnesis_md)

        { ok: true, summary_md: summary_md }
      end
    end
  end
end
