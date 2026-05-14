module Agent
  module Tools
    # Raw JSON Schema fragments shared by the periodization tools. Mirrors
    # `PeriodizationVersion::Generatable::SCHEMA` and `WORKOUT_SCHEMA`:
    # the same blocks discriminated-union vocabulary, the same workout
    # object shape (name + position + blocks for full plans; name + blocks
    # for single-workout patches). Per-kind block requirements are enforced
    # post-parse by `Workout::Blocks.errors_for`; the schema only constrains
    # the vocabulary because most providers do not honor `oneOf`.
    module PeriodizationSchema
      module_function

      GROUP_ITEM = {
        type: "object",
        additionalProperties: false,
        required: %w[name prescription],
        properties: {
          name:         { type: "string" },
          prescription: { type: "string" },
          notes:        { type: "string" }
        }
      }.freeze

      BLOCK = {
        type: "object",
        additionalProperties: false,
        required: %w[kind],
        properties: {
          kind:         { type: "string", enum: %w[exercise group freeform] },
          name:         { type: "string" },
          prescription: { type: "string" },
          rest_s:       { type: "integer" },
          notes:        { type: "string" },
          label:        { type: "string" },
          rounds:       { type: "integer" },
          items:        { type: "array", items: GROUP_ITEM },
          text_md:      { type: "string" }
        }
      }.freeze

      WORKOUT_OBJECT = {
        type: "object",
        additionalProperties: false,
        required: %w[name blocks position],
        properties: {
          name:     { type: "string" },
          blocks:   { type: "array", items: BLOCK },
          position: { type: "integer" }
        }
      }.freeze

      def full_plan_params
        {
          type: "object",
          additionalProperties: false,
          required: %w[body_md workouts summary_md],
          properties: {
            body_md:    { type: "string", description: "Markdown do plano (visão geral do mesociclo, princípios, progressão). Não comece com título H1." },
            workouts:   { type: "array", items: WORKOUT_OBJECT, description: "Lista de treinos, cada um com name, position (>= 1) e blocks." },
            summary_md: { type: "string", description: "Frase curta em pt-BR resumindo o que mudou. Aparece no card do chat." }
          }
        }
      end

      def workout_patch_params
        {
          type: "object",
          additionalProperties: false,
          required: %w[workout_id name blocks summary_md],
          properties: {
            workout_id: { type: "string", description: "UUID do treino a editar dentro da current_version da periodização ativa do aluno." },
            name:       { type: "string", description: "Novo nome do treino." },
            blocks:     { type: "array", items: BLOCK, description: "Nova lista de blocos do treino." },
            summary_md: { type: "string", description: "Frase curta em pt-BR resumindo o que mudou. Aparece no card do chat." }
          }
        }
      end
    end
  end
end
