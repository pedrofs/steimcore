# Claude boundary for periodization generation owned by the version. Builds a
# pt-BR prompt, asks Claude — via RubyLLM with a schema — for a structured
# patch, and applies the patch to this version through Forkable.
#
# Scope is detected from the version's voice_recording's kind:
#   periodization_create             → :create        — full plan schema
#   periodization_edit_workout       → :workout       — single-workout patch;
#                                                       the targeted workout
#                                                       (target_workout_id on
#                                                       the recording) is
#                                                       replaced inside the
#                                                       carry-forward done by
#                                                       Forkable
#   periodization_edit_periodization → :periodization — same full-plan schema
#                                                       as :create; previous
#                                                       workouts are NOT carried
#                                                       forward
#
# Any schema-invalid response or RubyLLM error marks the version :failed with
# the message preserved for retry.
module PeriodizationVersion::Generatable
  extend ActiveSupport::Concern

  MODEL = "claude-opus-4-7"

  GROUP_ITEM_SCHEMA = {
    type: "object",
    additionalProperties: false,
    required: %w[name prescription],
    properties: {
      name:         { type: "string" },
      prescription: { type: "string" },
      notes:        { type: "string" }
    }
  }.freeze

  # Flat discriminated union — `kind` selects which other fields apply.
  # Per-kind requirements and field-omission rules are enforced post-parse by
  # Workout::Blocks.errors_for; the schema only constrains the vocabulary
  # because most LLMs do not support JSON Schema `oneOf`.
  BLOCK_SCHEMA = {
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
      items:        { type: "array", items: GROUP_ITEM_SCHEMA },
      text_md:      { type: "string" }
    }
  }.freeze

  WORKOUT_OBJECT_SCHEMA = {
    type: "object",
    additionalProperties: false,
    required: %w[name blocks position],
    properties: {
      name:     { type: "string" },
      blocks:   { type: "array", items: BLOCK_SCHEMA },
      position: { type: "integer" }
    }
  }.freeze

  SCHEMA = {
    name: "periodization_plan",
    schema: {
      type: "object",
      additionalProperties: false,
      required: %w[body_md workouts],
      properties: {
        body_md:  { type: "string" },
        workouts: { type: "array", items: WORKOUT_OBJECT_SCHEMA }
      }
    }
  }.freeze

  WORKOUT_SCHEMA = {
    name: "periodization_workout_patch",
    schema: {
      type: "object",
      additionalProperties: false,
      required: %w[workout],
      properties: {
        workout: {
          type: "object",
          additionalProperties: false,
          required: %w[name blocks],
          properties: {
            name:   { type: "string" },
            blocks: { type: "array", items: BLOCK_SCHEMA }
          }
        }
      }
    }
  }.freeze

  BLOCKS_EXAMPLE = <<~JSON.freeze
    [
      { "kind": "freeform", "text_md": "Aquecimento livre 5-10 min" },
      { "kind": "exercise", "name": "Supino reto",
        "prescription": "3 × 8-10", "rest_s": 90, "notes": "tempo 3-0-1" },
      { "kind": "group", "label": "Superset A", "rounds": 3,
        "items": [
          { "name": "Rosca direta", "prescription": "10 reps" },
          { "name": "Tríceps testa", "prescription": "10 reps" }
        ] }
    ]
  JSON

  EXERCISE_NAMING = <<~TEXT.freeze
    Diretrizes para o campo `name` de exercícios (vale tanto em blocos
    `exercise` quanto em `items` de blocos `group`):
    - Use o nome canônico e curto do exercício, do jeito que um treinador
      escreveria numa ficha. Inclua apenas variações que mudam o estímulo
      principal — ângulo do banco (inclinado/declinado), tipo de carga
      quando há outra versão clássica (c/ halteres, c/ barra, na polia,
      na máquina), unilateral, pegada quando muda o exercício.
    - Use "c/" como abreviação de "com".
    - NÃO coloque no `name`: postura específica, alternativas de
      equipamento, tradução em inglês entre parênteses, descrição da
      pegada/apoio quando é a padrão, intensidade da carga, tempo, ou
      qualquer detalhe secundário. Tudo isso vai em `notes` (uma frase
      curta).
    - Omita `notes` quando não há detalhe relevante.

    Exemplos de normalização:
    - "Elevação pélvica com barra olímpica no suporte (hip thrust)"
      → name: "Elevação pélvica"  (omitir notes)
    - "Afundo (lunge) com halteres em suspensão, em apoio fixo no step"
      → name: "Afundo c/ halteres", notes: "apoio fixo no step"
    - "Panturrilha em pé na máquina ou no step com halteres em suspensão"
      → name: "Panturrilha em pé"  (omitir notes)
    - "Crucifixo na polia baixa (cross-over), tronco levemente inclinado"
      → name: "Crucifixo na polia", notes: "tronco levemente inclinado"
    - "Supino com halteres leves no banco inclinado baixo (≤ 30°)"
      → name: "Supino inclinado c/ halteres", notes: "banco baixo (≤ 30°), carga leve"
  TEXT

  class InvalidPlanError < StandardError; end

  def generate!
    return unless status == "generating"

    case voice_recording&.kind
    when "periodization_edit_workout"
      run_workout_edit!
    when "periodization_edit_periodization"
      run_periodization_edit!
    else
      run_create!
    end
  rescue StandardError => e
    fail!(e.message.presence || e.class.name)
    raise if Rails.env.test? && ENV["RAISE_JOB_ERRORS"] == "true"
  end

  private
    def run_create!
      student = periodization.student
      organization = student.organization
      recording = voice_recording

      chat = RubyLLM.chat(model: MODEL).with_instructions(create_system_prompt).with_schema(SCHEMA)
      response = chat.ask(create_user_prompt(student, organization, recording&.transcript.to_s))

      plan = parse_response(response.content)
      validate_create_plan!(plan)

      fork_with!(
        scope: :create,
        patch: plan,
        trainer: trainer,
        voice_recording: recording
      )
      complete!
    end

    def run_workout_edit!
      recording = voice_recording
      target_workout = recording.target_workout
      raise InvalidPlanError, "voice recording missing target_workout" if target_workout.nil?
      raise InvalidPlanError, "edit version missing parent_version" if parent_version.nil?

      student = periodization.student
      organization = student.organization

      chat = RubyLLM.chat(model: MODEL).with_instructions(workout_system_prompt).with_schema(WORKOUT_SCHEMA)
      response = chat.ask(
        workout_user_prompt(student, organization, parent_version, target_workout, recording.transcript.to_s)
      )

      patch = parse_response(response.content)
      validate_workout_patch!(patch)

      fork_with!(
        scope: :workout,
        patch: patch,
        trainer: trainer,
        voice_recording: recording,
        target_workout: target_workout
      )
      complete!
    end

    def run_periodization_edit!
      recording = voice_recording
      raise InvalidPlanError, "edit version missing parent_version" if parent_version.nil?

      student = periodization.student
      organization = student.organization

      chat = RubyLLM.chat(model: MODEL).with_instructions(periodization_edit_system_prompt).with_schema(SCHEMA)
      response = chat.ask(periodization_edit_user_prompt(student, organization, parent_version, recording.transcript.to_s))

      plan = parse_response(response.content)
      validate_create_plan!(plan)

      fork_with!(
        scope: :periodization,
        patch: plan,
        trainer: trainer,
        voice_recording: recording
      )
      complete!
    end

    def parse_response(content)
      case content
      when Hash then content
      when String
        begin
          JSON.parse(content)
        rescue JSON::ParserError => e
          raise InvalidPlanError, "resposta não é JSON válido: #{e.message}"
        end
      else
        raise InvalidPlanError, "resposta vazia"
      end
    end

    def validate_create_plan!(plan)
      raise InvalidPlanError, "campo body_md ausente" unless plan["body_md"].is_a?(String) || plan[:body_md].is_a?(String)

      workouts = plan["workouts"] || plan[:workouts]
      raise InvalidPlanError, "campo workouts ausente ou inválido" unless workouts.is_a?(Array) && workouts.any?

      workouts.each_with_index do |w, i|
        name = w["name"] || w[:name]
        blocks = w["blocks"] || w[:blocks]
        position = w["position"] || w[:position]

        raise InvalidPlanError, "workout #{i}: nome inválido" unless name.is_a?(String) && !name.strip.empty?
        raise InvalidPlanError, "workout #{i}: position inválida" unless position.is_a?(Integer)

        block_errors = Workout::Blocks.errors_for(blocks)
        raise InvalidPlanError, "workout #{i}: #{block_errors.join('; ')}" if block_errors.any?
      end
    end

    def validate_workout_patch!(patch)
      workout = patch["workout"] || patch[:workout]
      raise InvalidPlanError, "campo workout ausente ou inválido" unless workout.is_a?(Hash)

      name = workout["name"] || workout[:name]
      blocks = workout["blocks"] || workout[:blocks]

      raise InvalidPlanError, "workout: nome inválido" unless name.is_a?(String) && !name.strip.empty?

      block_errors = Workout::Blocks.errors_for(blocks)
      raise InvalidPlanError, "workout: #{block_errors.join('; ')}" if block_errors.any?
    end

    def create_system_prompt
      <<~PROMPT
        Você é um assistente de um personal trainer numa academia de musculação.
        Sua tarefa é montar uma periodização de treino para um aluno, em
        português do Brasil. A saída deve ser um plano estruturado com um corpo
        em markdown (visão geral do mesociclo, princípios, progressão) e uma
        lista de treinos (A, B, C, …), cada um com nome curto, posição inteira
        a partir de 1 e uma lista estruturada de blocos.

        O body_md não deve começar com um título de nível 1
        (ex.: "# Periodização — <nome>"); comece direto pelas seções de
        nível 2 (##).

        Cada bloco é um dos três tipos:
        - exercise: um exercício individual com name (nome do exercício),
          prescription (volume/intensidade como "3 × 8-10", "5x5 @ 80%",
          "EMOM 10min", incluindo RPE/RIR se relevante), e opcionalmente
          rest_s (descanso em segundos) e notes (observação curta).
        - group: rotações multi-exercício (superset, circuito, giant set).
          Tem items (lista de exercícios { name, prescription, notes? }),
          opcionalmente label (ex.: "Superset A") e rounds (rodadas).
        - freeform: texto em markdown para conteúdo que não cabe em linha
          (aquecimento, mobilidade, observações de bloco/deload).

        Cada bloco deve conter APENAS as propriedades listadas para o seu
        kind. Não misture campos de kinds diferentes (ex.: não inclua
        text_md num exercise, nem items num freeform). Campos opcionais
        devem ser omitidos quando não se aplicam.

        Não inclua carga em kg — o treinador anota à mão por sessão. Não use
        propriedades fora do esquema. Use apenas equipamentos disponíveis na
        academia. Não invente dados que o treinador não tenha mencionado.
        Não mencione que você é uma IA.

        #{EXERCISE_NAMING}
        Exemplo de lista de blocos para um treino:
        #{BLOCKS_EXAMPLE}
      PROMPT
    end

    def create_user_prompt(student, organization, transcript)
      <<~PROMPT
        ## Aluno
        Nome: #{student.name}
        Idade: #{student.age || "(não informada)"}
        Sexo: #{student.sex || "(não informado)"}
        Objetivo principal: #{student.primary_goal || "(não informado)"}
        Frequência semanal: #{student.weekly_frequency || "(não informada)"}
        Restrições resumidas: #{student.restrictions_summary.presence || "(nenhuma)"}

        ## Anamnese atual
        #{student.anamnesis_md.presence || "(vazia)"}

        ## Equipamentos da academia
        #{organization.equipment_list_md.presence || "(não informado)"}

        ## Instruções do treinador (transcritas)
        #{transcript.presence || "(vazias)"}

        ## Tarefa
        Gere a periodização estruturada. Inclua um body_md com o plano geral e
        a lista de treinos (workouts), cada um com name, position e blocks
        (lista de blocos exercise/group/freeform), numerados em ordem de
        execução semanal.
      PROMPT
    end

    def workout_system_prompt
      <<~PROMPT
        Você é um assistente de um personal trainer numa academia de musculação.
        Sua tarefa é editar UM treino específico de uma periodização existente,
        em português do Brasil. Receberá o plano completo (body markdown e
        todos os treinos com seus blocos) como contexto e a instrução do
        treinador. Devolva apenas o conteúdo novo do treino em questão, com
        name curto e blocks (lista estruturada de blocos).

        Cada bloco é um dos três tipos:
        - exercise: { kind, name, prescription, rest_s?, notes? }
        - group:    { kind, label?, rounds?, items: [{ name, prescription, notes? }] }
        - freeform: { kind, text_md }

        Cada bloco deve conter APENAS as propriedades listadas para o seu
        kind. Não misture campos de kinds diferentes (ex.: não inclua
        text_md num exercise, nem items num freeform). Campos opcionais
        devem ser omitidos quando não se aplicam.

        Não devolva os outros treinos nem o body. Não inclua carga em kg. Use
        apenas equipamentos disponíveis na academia. Não invente dados que o
        treinador não tenha mencionado. Não mencione que você é uma IA.

        #{EXERCISE_NAMING}
        Exemplo de lista de blocos para um treino:
        #{BLOCKS_EXAMPLE}
      PROMPT
    end

    def workout_user_prompt(student, organization, parent_version, target_workout, transcript)
      workouts_block = parent_version.workouts.order(:position).map { |w|
        "### Treino #{w.name} (posição #{w.position})\n#{format_blocks_for_prompt(w.blocks)}"
      }.join("\n\n")

      <<~PROMPT
        ## Aluno
        Nome: #{student.name}
        Idade: #{student.age || "(não informada)"}
        Sexo: #{student.sex || "(não informado)"}
        Objetivo principal: #{student.primary_goal || "(não informado)"}
        Frequência semanal: #{student.weekly_frequency || "(não informada)"}
        Restrições resumidas: #{student.restrictions_summary.presence || "(nenhuma)"}

        ## Anamnese atual
        #{student.anamnesis_md.presence || "(vazia)"}

        ## Equipamentos da academia
        #{organization.equipment_list_md.presence || "(não informado)"}

        ## Periodização atual (versão #{parent_version.id})
        #{parent_version.body_md.presence || "(vazia)"}

        ## Treinos atuais
        #{workouts_block.presence || "(nenhum)"}

        ## Treino a editar
        Nome atual: #{target_workout.name}
        Posição: #{target_workout.position}

        ## Instruções do treinador (transcritas)
        #{transcript.presence || "(vazias)"}

        ## Tarefa
        Devolva apenas o novo conteúdo do treino na posição
        #{target_workout.position}, no formato { workout: { name, blocks } }.
      PROMPT
    end

    def periodization_edit_system_prompt
      <<~PROMPT
        Você é um assistente de um personal trainer numa academia de musculação.
        Sua tarefa é REVISAR uma periodização existente, em português do Brasil,
        aplicando as instruções do treinador. Devolva o plano completo
        atualizado: body markdown (visão geral do mesociclo, princípios,
        progressão) e a lista completa de treinos (A, B, C, …), cada um com
        name curto, position inteira a partir de 1 e blocks (lista estruturada
        de blocos).

        O body_md não deve começar com um título de nível 1
        (ex.: "# Periodização — <nome>"); comece direto pelas seções de
        nível 2 (##).

        Cada bloco é um dos três tipos:
        - exercise: { kind, name, prescription, rest_s?, notes? }
        - group:    { kind, label?, rounds?, items: [{ name, prescription, notes? }] }
        - freeform: { kind, text_md }

        Cada bloco deve conter APENAS as propriedades listadas para o seu
        kind. Não misture campos de kinds diferentes (ex.: não inclua
        text_md num exercise, nem items num freeform). Campos opcionais
        devem ser omitidos quando não se aplicam.

        O resultado substitui o plano anterior por inteiro: você pode
        adicionar, remover, renomear ou reordenar treinos conforme necessário.
        Não inclua carga em kg. Use apenas equipamentos disponíveis na
        academia. Não invente dados que o treinador não tenha mencionado. Não
        mencione que você é uma IA.

        #{EXERCISE_NAMING}
        Exemplo de lista de blocos para um treino:
        #{BLOCKS_EXAMPLE}
      PROMPT
    end

    def periodization_edit_user_prompt(student, organization, parent_version, transcript)
      workouts_block = parent_version.workouts.order(:position).map { |w|
        "### Treino #{w.name} (posição #{w.position})\n#{format_blocks_for_prompt(w.blocks)}"
      }.join("\n\n")

      <<~PROMPT
        ## Aluno
        Nome: #{student.name}
        Idade: #{student.age || "(não informada)"}
        Sexo: #{student.sex || "(não informado)"}
        Objetivo principal: #{student.primary_goal || "(não informado)"}
        Frequência semanal: #{student.weekly_frequency || "(não informada)"}
        Restrições resumidas: #{student.restrictions_summary.presence || "(nenhuma)"}

        ## Anamnese atual
        #{student.anamnesis_md.presence || "(vazia)"}

        ## Equipamentos da academia
        #{organization.equipment_list_md.presence || "(não informado)"}

        ## Periodização atual (versão #{parent_version.id})
        #{parent_version.body_md.presence || "(vazia)"}

        ## Treinos atuais
        #{workouts_block.presence || "(nenhum)"}

        ## Instruções do treinador (transcritas)
        #{transcript.presence || "(vazias)"}

        ## Tarefa
        Devolva o plano completo atualizado, com body_md e a lista de workouts
        (cada um com name, position e blocks), numerados em ordem de execução
        semanal. Você pode adicionar, remover ou reordenar treinos conforme as
        instruções do treinador.
      PROMPT
    end

    def format_blocks_for_prompt(blocks)
      return "(vazio)" if blocks.blank?
      JSON.pretty_generate(blocks)
    end
end
