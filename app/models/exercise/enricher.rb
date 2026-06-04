# A single structured `RubyLLM` call that proposes taxonomy (one Exercise family
# + one primary Muscle group) for an Unenriched Exercise the Linker minted
# without trigram candidates — the case the `Exercise::Linker::Classifier` never
# sees, since it only runs on names that already have candidates. This is the
# backfill path that gives those blind-minted Exercises a taxonomy.
#
# The existing Family and Muscle group vocabularies are enumerated into the
# prompt (small controlled tables) so the model reuses an existing node verbatim
# when one fits; `Exercise::Family.for_name` / `Exercise::MuscleGroup.for_name`
# dedup on the Normalized key regardless, so a near-miss spelling still collapses
# onto the same node. The public API stays on the model
# (`exercise.enrich_taxonomy!`); this is its private collaborator.
#
# The real LLM call is covered at the system level; unit tests stub `.classify`.
class Exercise::Enricher
  # Matches the Linker's tier (`Exercise::Linker::Classifier`).
  MODEL = "claude-opus-4-7"

  # A flat object: the family and muscle group names, free-text. Reuse is handled
  # downstream by `for_name`, so the model just names the best fit rather than
  # juggling existing-id-vs-new like the Classifier does.
  class TaxonomySchema < RubyLLM::Schema
    string :family,
           description: "Nome da Exercise family do movimento (ex.: \"Supino\", \"Agachamento\"). Reutilize um nome existente quando algum servir."
    string :muscle_group,
           description: "Nome do Muscle group primário trabalhado (ex.: \"Peito\", \"Quadríceps\"). Reutilize um nome existente quando algum servir."
  end

  SYSTEM_PROMPT = <<~PROMPT.freeze
    Você classifica exercícios de musculação em um catálogo. Dado o nome de UM
    exercício, devolva a Exercise family a que ele pertence e o Muscle group
    primário que ele trabalha.

    Regras:
    - Reutilize EXATAMENTE um nome das listas de families/muscle groups existentes
      quando algum descrever o movimento; só proponha um nome novo quando nenhum
      dos existentes servir.
    - Escolha UMA family e UM muscle group primário (sem sinergistas).
    - Use nomes curtos e canônicos em português.
  PROMPT

  def self.classify(exercise)
    new(exercise).classify
  end

  def initialize(exercise)
    @exercise = exercise
  end

  def classify
    chat = RubyLLM.chat(model: MODEL)
    chat.with_schema(TaxonomySchema)
    chat.with_instructions(SYSTEM_PROMPT)
    response = chat.ask(payload.to_json)

    decision_from(response.content)
  end

  private
    def payload
      {
        exercise_families: Exercise::Family.order(:name).pluck(:name),
        muscle_groups: Exercise::MuscleGroup.order(:name).pluck(:name),
        exercise_name: @exercise.name
      }
    end

    def decision_from(content)
      return {} unless content.is_a?(Hash)

      row = content.symbolize_keys
      { family: row[:family], muscle_group: row[:muscle_group] }
    end
end
