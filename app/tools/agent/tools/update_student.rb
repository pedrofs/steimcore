module Agent
  module Tools
    # Updates the student's structured demographic and contact fields:
    # birthday, sex, primary_goal, weekly_frequency, phone, email. All
    # fields are optional — only those passed in the call are touched.
    # `notes_md` and `anamnesis_md` are intentionally NOT covered here;
    # the anamnese has its own dedicated tool and notes_md is reserved
    # for a future LLM-memory mechanism.
    #
    # The agent writes a short pt-BR `summary_md` describing what changed
    # and the chat card surfaces that sentence verbatim.
    class UpdateStudent < RubyLLM::Tool
      description <<~DESC
        Atualiza os dados estruturados do aluno: data de nascimento
        (`birthday` em formato ISO YYYY-MM-DD), sexo (`sex`), objetivo
        principal (`primary_goal`), frequência semanal alvo
        (`weekly_frequency`, inteiro de 0 a 7), telefone (`phone`) e
        e-mail (`email`). Todos os campos são opcionais — passe apenas os
        que devem mudar. Use string vazia para limpar um campo de texto e
        0 para limpar a frequência. Não use esta ferramenta para anamnese
        nem para observações livres.
      DESC

      params(
        type: "object",
        additionalProperties: false,
        required: %w[summary_md],
        properties: {
          birthday:         { type: "string", description: "Data de nascimento em ISO 8601 (YYYY-MM-DD). Use string vazia para limpar." },
          sex:              { type: "string", description: "Sexo do aluno (ex.: Feminino, Masculino). String vazia limpa." },
          primary_goal:     { type: "string", description: "Objetivo principal (ex.: Hipertrofia, Emagrecimento). String vazia limpa." },
          weekly_frequency: { type: "integer", description: "Frequência semanal alvo (0 a 7). Use 0 para limpar." },
          phone:            { type: "string", description: "Telefone do aluno. String vazia limpa." },
          email:            { type: "string", description: "E-mail do aluno. String vazia limpa." },
          summary_md:       { type: "string", description: "Frase curta em pt-BR resumindo o que mudou. Aparece no card do chat." }
        }
      )

      WEEKLY_FREQUENCY_RANGE = (0..7)

      def name
        "update_student"
      end

      def initialize(student:, trainer:)
        super()
        @student = student
        @trainer = trainer
      end

      def execute(summary_md:, **fields)
        summary_md = summary_md.to_s.strip
        return { error: "Faltou um resumo curto (`summary_md`) descrevendo a alteração." } if summary_md.empty?

        attrs, error = build_attrs(fields)
        return { error: error } if error
        return { error: "Nenhum campo informado para atualizar." } if attrs.empty?

        @student.update!(attrs)

        { ok: true, summary_md: summary_md, updated_fields: attrs.keys.map(&:to_s) }
      end

      private
        def build_attrs(fields)
          attrs = {}

          if fields.key?(:birthday)
            raw = fields[:birthday].to_s.strip
            if raw.empty?
              attrs[:birthday] = nil
            else
              begin
                attrs[:birthday] = Date.iso8601(raw)
              rescue Date::Error
                return [ nil, "Data de nascimento inválida: use o formato YYYY-MM-DD." ]
              end
            end
          end

          if fields.key?(:weekly_frequency)
            value = fields[:weekly_frequency]
            return [ nil, "Frequência semanal precisa ser um inteiro." ] unless value.is_a?(Integer)
            return [ nil, "Frequência semanal precisa estar entre 0 e 7." ] unless WEEKLY_FREQUENCY_RANGE.cover?(value)
            attrs[:weekly_frequency] = value.zero? ? nil : value
          end

          %i[sex primary_goal phone email].each do |key|
            next unless fields.key?(key)
            raw = fields[key].to_s
            attrs[key] = raw.strip.empty? ? nil : raw
          end

          [ attrs, nil ]
        end
    end
  end
end
