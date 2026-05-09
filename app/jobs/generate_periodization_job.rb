# Claude boundary for periodization generation. Receives a PeriodizationVersion
# in :generating with a confirmed transcript on its voice_recording, builds a
# pt-BR prompt, asks Claude — via RubyLLM with a schema — for a structured
# patch, and applies the patch to the version through Forkable.
#
# Scope is detected from the voice_recording's kind:
#   periodization_create             → :create        → schema for full plan
#   periodization_edit_workout       → :workout       → schema for one workout's
#                                                       { name, content_md };
#                                                       the targeted workout
#                                                       (target_workout_id on
#                                                       the recording) is
#                                                       replaced inside the
#                                                       carry-forward done by
#                                                       Forkable.
#   periodization_edit_periodization → :periodization → same full-plan schema
#                                                       as :create; previous
#                                                       workouts are NOT carried
#                                                       forward, the new plan
#                                                       fully replaces the old.
#
# Any schema-invalid response or RubyLLM error marks the version :failed with
# the message preserved for retry.
class GeneratePeriodizationJob < ApplicationJob
  queue_as :default

  MODEL = "claude-sonnet-4-5"

  SCHEMA = {
    name: "periodization_plan",
    schema: {
      type: "object",
      additionalProperties: false,
      required: %w[body_md workouts],
      properties: {
        body_md: { type: "string" },
        workouts: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: %w[name content_md position],
            properties: {
              name: { type: "string" },
              content_md: { type: "string" },
              position: { type: "integer" }
            }
          }
        }
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
          required: %w[name content_md],
          properties: {
            name: { type: "string" },
            content_md: { type: "string" }
          }
        }
      }
    }
  }.freeze

  def perform(version_id)
    version = PeriodizationVersion.find(version_id)
    return unless version.status == "generating"

    student = version.periodization.student
    organization = student.organization
    recording = version.voice_recording

    case recording&.kind
    when "periodization_edit_workout"
      run_workout_edit!(version, student, organization, recording)
    when "periodization_edit_periodization"
      run_periodization_edit!(version, student, organization, recording)
    else
      run_create!(version, student, organization, recording)
    end
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    version&.fail!(e.message.presence || e.class.name)
    raise if Rails.env.test? && ENV["RAISE_JOB_ERRORS"] == "true"
  end

  private
    def run_create!(version, student, organization, recording)
      chat = RubyLLM.chat(model: MODEL).with_instructions(create_system_prompt).with_schema(SCHEMA)
      response = chat.ask(create_user_prompt(student, organization, recording&.transcript.to_s))

      plan = parse_response(response.content)
      validate_create_plan!(plan)

      version.fork_with!(
        scope: :create,
        patch: plan,
        trainer: version.trainer,
        voice_recording: recording
      )
      version.transition_to!(:completed)
    end

    def run_workout_edit!(version, student, organization, recording)
      target_workout = recording.target_workout
      raise InvalidPlanError, "voice recording missing target_workout" if target_workout.nil?

      parent_version = version.parent_version
      raise InvalidPlanError, "edit version missing parent_version" if parent_version.nil?

      chat = RubyLLM.chat(model: MODEL).with_instructions(workout_system_prompt).with_schema(WORKOUT_SCHEMA)
      response = chat.ask(
        workout_user_prompt(student, organization, parent_version, target_workout, recording.transcript.to_s)
      )

      patch = parse_response(response.content)
      validate_workout_patch!(patch)

      version.fork_with!(
        scope: :workout,
        patch: patch,
        trainer: version.trainer,
        voice_recording: recording,
        target_workout: target_workout
      )
      version.transition_to!(:completed)
    end

    def run_periodization_edit!(version, student, organization, recording)
      parent_version = version.parent_version
      raise InvalidPlanError, "edit version missing parent_version" if parent_version.nil?

      chat = RubyLLM.chat(model: MODEL).with_instructions(periodization_edit_system_prompt).with_schema(SCHEMA)
      response = chat.ask(periodization_edit_user_prompt(student, organization, parent_version, recording.transcript.to_s))

      plan = parse_response(response.content)
      validate_create_plan!(plan)

      version.fork_with!(
        scope: :periodization,
        patch: plan,
        trainer: version.trainer,
        voice_recording: recording
      )
      version.transition_to!(:completed)
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
        content_md = w["content_md"] || w[:content_md]
        position = w["position"] || w[:position]

        raise InvalidPlanError, "workout #{i}: nome inválido" unless name.is_a?(String) && !name.strip.empty?
        raise InvalidPlanError, "workout #{i}: content_md inválido" unless content_md.is_a?(String)
        raise InvalidPlanError, "workout #{i}: position inválida" unless position.is_a?(Integer)
      end
    end

    def validate_workout_patch!(patch)
      workout = patch["workout"] || patch[:workout]
      raise InvalidPlanError, "campo workout ausente ou inválido" unless workout.is_a?(Hash)

      name = workout["name"] || workout[:name]
      content_md = workout["content_md"] || workout[:content_md]

      raise InvalidPlanError, "workout: nome inválido" unless name.is_a?(String) && !name.strip.empty?
      raise InvalidPlanError, "workout: content_md inválido" unless content_md.is_a?(String)
    end

    def create_system_prompt
      <<~PROMPT
        Você é um assistente de um personal trainer numa academia de musculação.
        Sua tarefa é montar uma periodização de treino para um aluno, em
        português do Brasil. A saída deve ser um plano estruturado com um corpo
        em markdown (visão geral do mesociclo, princípios, progressão) e uma
        lista de treinos (A, B, C, …), cada um com nome curto, conteúdo em
        markdown (lista de exercícios, séries, repetições, observações) e uma
        posição inteira a partir de 1. Use apenas equipamentos disponíveis na
        academia. Não invente dados que o treinador não tenha mencionado. Não
        mencione que você é uma IA.
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
        a lista de treinos (workouts) numerados em ordem de execução semanal.
      PROMPT
    end

    def workout_system_prompt
      <<~PROMPT
        Você é um assistente de um personal trainer numa academia de musculação.
        Sua tarefa é editar UM treino específico de uma periodização existente,
        em português do Brasil. Receberá o plano completo (body markdown e
        todos os treinos) como contexto e a instrução do treinador. Devolva
        apenas o conteúdo novo do treino em questão, com nome curto e conteúdo
        em markdown (lista de exercícios, séries, repetições, observações).
        Não devolva os outros treinos nem o body. Use apenas equipamentos
        disponíveis na academia. Não invente dados que o treinador não tenha
        mencionado. Não mencione que você é uma IA.
      PROMPT
    end

    def workout_user_prompt(student, organization, parent_version, target_workout, transcript)
      workouts_block = parent_version.workouts.order(:position).map { |w|
        "### Treino #{w.name} (posição #{w.position})\n#{w.content_md.presence || '(vazio)'}"
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
        #{target_workout.position}, no formato { workout: { name, content_md } }.
      PROMPT
    end

    def periodization_edit_system_prompt
      <<~PROMPT
        Você é um assistente de um personal trainer numa academia de musculação.
        Sua tarefa é REVISAR uma periodização existente, em português do Brasil,
        aplicando as instruções do treinador. Devolva o plano completo
        atualizado: body markdown (visão geral do mesociclo, princípios,
        progressão) e a lista completa de treinos (A, B, C, …), cada um com
        nome curto, conteúdo em markdown (lista de exercícios, séries,
        repetições, observações) e uma posição inteira a partir de 1. O
        resultado substitui o plano anterior por inteiro: você pode adicionar,
        remover, renomear ou reordenar treinos conforme necessário. Use apenas
        equipamentos disponíveis na academia. Não invente dados que o treinador
        não tenha mencionado. Não mencione que você é uma IA.
      PROMPT
    end

    def periodization_edit_user_prompt(student, organization, parent_version, transcript)
      workouts_block = parent_version.workouts.order(:position).map { |w|
        "### Treino #{w.name} (posição #{w.position})\n#{w.content_md.presence || '(vazio)'}"
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
        (numerados em ordem de execução semanal). Você pode adicionar, remover
        ou reordenar treinos conforme as instruções do treinador.
      PROMPT
    end

    class InvalidPlanError < StandardError; end
end
