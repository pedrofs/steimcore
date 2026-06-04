require "test_helper"

class PeriodizationVersion::LinkableTest < ActiveSupport::TestCase
  setup do
    @student = students(:alice)
    @trainer = users(:one)
    @periodization = @student.periodizations.create!
    @version = @periodization.versions.create!(trainer: @trainer, parent_version: nil)
  end

  # ---- #exercise_names ------------------------------------------------------

  test "exercise_names collects names from exercise blocks and group items" do
    @version.workouts.create!(name: "A", position: 1, blocks: [
      exercise("Supino reto", "4x8"),
      group("Tríceps", [ item("Tríceps corda", "3x12"), item("Tríceps testa", "3x12") ])
    ])

    assert_equal %w[Supino\ reto Tríceps\ corda Tríceps\ testa].sort, @version.exercise_names.sort
  end

  test "exercise_names ignores freeform blocks" do
    @version.workouts.create!(name: "A", position: 1, blocks: [
      exercise("Agachamento", "5x5"),
      freeform("Aqueça 10 minutos na esteira.")
    ])

    assert_equal [ "Agachamento" ], @version.exercise_names
  end

  test "exercise_names dedups by normalized key across workouts" do
    @version.workouts.create!(name: "A", position: 1, blocks: [ exercise("Supino reto", "4x8") ])
    @version.workouts.create!(name: "B", position: 2, blocks: [ exercise("  SUPÍNO   RETO ", "3x10") ])

    assert_equal 1, @version.exercise_names.length
    assert_equal "Supino reto", @version.exercise_names.first
  end

  # ---- #link_exercises! -----------------------------------------------------

  test "link_exercises! mints an unenriched exercise for each unlinked name" do
    @version.workouts.create!(name: "A", position: 1, blocks: [
      exercise("Supino reto", "4x8"),
      group("Bíceps", [ item("Rosca direta", "3x12") ])
    ])

    assert_difference -> { Exercise.count }, 2 do
      @version.link_exercises!
    end

    supino = Exercise.resolve("Supino reto")
    rosca  = Exercise.resolve("Rosca direta")
    assert_predicate supino, :unenriched?
    assert_predicate rosca, :unenriched?
  end

  test "link_exercises! is idempotent" do
    @version.workouts.create!(name: "A", position: 1, blocks: [ exercise("Leg press", "4x12") ])
    @version.link_exercises!

    assert_no_difference -> { Exercise.count } do
      @version.link_exercises!
    end
  end

  test "link_exercises! skips names already resolvable in the catalog" do
    existing = Exercise.create!(name: "Supino reto")
    @version.workouts.create!(name: "A", position: 1, blocks: [
      exercise("supino reto", "4x8"),
      exercise("Crucifixo", "3x12")
    ])

    assert_difference -> { Exercise.count }, 1 do
      @version.link_exercises!
    end

    assert_equal existing, Exercise.resolve("Supino reto")
  end

  test "two versions sharing a novel name cannot create two exercises" do
    blocks = [ exercise("Movimento inédito", "3x10") ]
    @version.workouts.create!(name: "A", position: 1, blocks: blocks)
    other = @periodization.versions.create!(trainer: @trainer, parent_version: nil)
    other.workouts.create!(name: "A", position: 1, blocks: blocks)

    @version.link_exercises!
    other.link_exercises!

    assert_equal 1, Exercise.where(name: "Movimento inédito").count
  end

  # ---- #link_exercises! with candidates (LLM Classifier, stubbed) -----------

  test "a name with no retrieval candidates mints without invoking the Classifier" do
    @version.workouts.create!(name: "A", position: 1, blocks: [
      exercise("Movimento totalmente inédito", "3x10")
    ])

    called = false
    Exercise::Linker::Classifier.stub(:classify, ->(_items) { called = true; [] }) do
      assert_difference -> { Exercise.count }, 1 do
        @version.link_exercises!
      end
    end

    assert_not called, "Classifier must not run when trigram retrieval found no candidates"
    assert_predicate Exercise.resolve("Movimento totalmente inédito"), :unenriched?
  end

  test "a blind mint enqueues taxonomy enrichment for the new exercise" do
    @version.workouts.create!(name: "A", position: 1, blocks: [
      exercise("Movimento totalmente inédito", "3x10")
    ])

    assert_enqueued_jobs 1, only: EnrichExerciseJob do
      @version.link_exercises!
    end

    minted = Exercise.resolve("Movimento totalmente inédito")
    assert_enqueued_with(job: EnrichExerciseJob, args: [ minted ])
  end

  test "a confident match attaches a new llm alias to the existing exercise" do
    supino = Exercise.create!(name: "Supino reto")
    @version.workouts.create!(name: "A", position: 1, blocks: [ exercise("Supino reto com barra", "4x8") ])

    decisions = ->(items) do
      items.map { |i| { id: i[:id], decision: "match", exercise_id: supino.id, confidence: 0.95 } }
    end

    assert_no_difference -> { Exercise.count } do
      Exercise::Linker::Classifier.stub(:classify, decisions) { @version.link_exercises! }
    end

    assert_equal supino, Exercise.resolve("Supino reto com barra")
    row = Exercise::Alias.find_by(normalized_key: Exercise.normalize_name("Supino reto com barra"))
    assert_equal "llm", row.source
    assert_in_delta 0.95, row.confidence, 0.001
  end

  test "a new decision mints an exercise with its family and muscle group" do
    Exercise.create!(name: "Supino reto") # surfaces as a candidate, routing the name to the Classifier
    @version.workouts.create!(name: "A", position: 1, blocks: [ exercise("Supino reto com halteres", "4x10") ])

    decisions = ->(items) do
      items.map do |i|
        { id: i[:id], decision: "new", display_name: "Supino reto com halteres",
          family: { new: "Supino" }, muscle_group: { new: "Peito" }, confidence: 0.4 }
      end
    end

    Exercise::Linker::Classifier.stub(:classify, decisions) { @version.link_exercises! }

    minted = Exercise.resolve("Supino reto com halteres")
    assert_not_nil minted
    assert_equal "Supino", minted.exercise_family.name
    assert_equal "Peito", minted.muscle_group.name
  end

  test "a new decision reuses an existing taxonomy node chosen by id" do
    family = Exercise::Family.create!(name: "Supino", normalized_key: Exercise.normalize_name("Supino"))
    Exercise.create!(name: "Supino reto")
    @version.workouts.create!(name: "A", position: 1, blocks: [ exercise("Supino reto com halteres", "4x10") ])

    decisions = ->(items) do
      items.map { |i| { id: i[:id], decision: "new", display_name: "Supino reto com halteres", family: { existing_id: family.id }, confidence: 0.5 } }
    end

    assert_no_difference -> { Exercise::Family.count } do
      Exercise::Linker::Classifier.stub(:classify, decisions) { @version.link_exercises! }
    end

    assert_equal family, Exercise.resolve("Supino reto com halteres").exercise_family
  end

  test "two new exercises assigned the same new taxonomy share a single node" do
    Exercise.create!(name: "Supino reto") # surfaces as a candidate for both variants
    @version.workouts.create!(name: "A", position: 1, blocks: [
      exercise("Supino reto com halteres", "4x10"),
      exercise("Supino reto com barra", "4x8")
    ])

    decisions = ->(items) do
      items.map { |i| { id: i[:id], decision: "new", display_name: i[:name], family: { new: "Supino" }, muscle_group: { new: "Peito" }, confidence: 0.3 } }
    end

    Exercise::Linker::Classifier.stub(:classify, decisions) { @version.link_exercises! }

    assert_equal 1, Exercise::Family.where(name: "Supino").count
    assert_equal 1, Exercise::MuscleGroup.where(name: "Peito").count
  end

  test "an uncertain decision mints rather than merging onto a candidate (bias to split)" do
    supino = Exercise.create!(name: "Supino reto")
    @version.workouts.create!(name: "A", position: 1, blocks: [ exercise("Supino reto com barra", "4x8") ])

    decisions = ->(items) do
      items.map { |i| { id: i[:id], decision: "new", display_name: i[:name], confidence: 0.2 } }
    end

    assert_difference -> { Exercise.count }, 1 do
      Exercise::Linker::Classifier.stub(:classify, decisions) { @version.link_exercises! }
    end

    assert_not_equal supino, Exercise.resolve("Supino reto com barra")
  end

  test "link_exercises! through the Classifier is idempotent" do
    Exercise.create!(name: "Supino reto")
    @version.workouts.create!(name: "A", position: 1, blocks: [ exercise("Supino reto com barra", "4x8") ])

    decisions = ->(items) { items.map { |i| { id: i[:id], decision: "new", display_name: i[:name], confidence: 0.5 } } }

    Exercise::Linker::Classifier.stub(:classify, decisions) { @version.link_exercises! }
    assert_no_difference -> { Exercise.count } do
      Exercise::Linker::Classifier.stub(:classify, decisions) { @version.link_exercises! }
    end
  end

  test "decisions are applied by stable id, not array position" do
    supino = Exercise.create!(name: "Supino reto")
    agacha = Exercise.create!(name: "Agachamento livre")
    @version.workouts.create!(name: "A", position: 1, blocks: [
      exercise("Supino reto com barra", "4x8"),
      exercise("Agachamento com barra", "5x5")
    ])

    decisions = ->(items) do
      by_id = {
        Exercise.normalize_name("Supino reto com barra") => supino.id,
        Exercise.normalize_name("Agachamento com barra") => agacha.id
      }
      # Reverse the order to prove matching is keyed by id, not position.
      items.reverse.map { |i| { id: i[:id], decision: "match", exercise_id: by_id[i[:id]], confidence: 0.9 } }
    end

    Exercise::Linker::Classifier.stub(:classify, decisions) { @version.link_exercises! }

    assert_equal supino, Exercise.resolve("Supino reto com barra")
    assert_equal agacha, Exercise.resolve("Agachamento com barra")
  end

  # ---- after_commit trigger -------------------------------------------------

  test "completing a version enqueues the linker once status becomes completed" do
    version = @periodization.versions.create!(trainer: @trainer, periodization_length_weeks: 8)
    version.transition_to!(:generating)

    assert_enqueued_with(job: LinkExercisesJob, args: [ version ]) do
      version.complete!
    end
  end

  test "a non-completing transition does not enqueue the linker" do
    version = @periodization.versions.create!(trainer: @trainer)

    assert_no_enqueued_jobs(only: LinkExercisesJob) do
      version.transition_to!(:generating)
    end
  end

  # ---- re-linking after edits to an already-completed version ---------------
  # A completed version's exercise content can change without any status
  # transition: the trainer inline-edits a workout's blocks, or the agent
  # mutates an editable draft in place via apply_patch!. The names change but
  # `saved_change_to_status?` stays false, so the status-only trigger misses
  # these. Linking must re-run whenever a completed version's blocks change.

  test "editing a completed version's workout blocks re-enqueues the linker" do
    version = completed_version_with_workout
    workout = version.workouts.first

    assert_enqueued_with(job: LinkExercisesJob, args: [ version ]) do
      workout.update!(blocks: [ exercise("Crucifixo", "3x12") ])
    end
  end

  test "apply_patch! on a completed draft re-enqueues the linker" do
    version = completed_version_with_workout
    patch = {
      body_md: "Plano revisado",
      periodization_length_weeks: 8,
      workouts: [ { name: "A", position: 1, blocks: [ exercise("Crucifixo", "3x12") ] } ]
    }

    assert_enqueued_with(job: LinkExercisesJob, args: [ version ]) do
      version.apply_patch!(scope: :periodization, patch: patch, trainer: @trainer)
    end
  end

  test "editing a workout without touching blocks does not enqueue the linker" do
    version = completed_version_with_workout
    workout = version.workouts.first

    assert_no_enqueued_jobs(only: LinkExercisesJob) do
      workout.update!(name: "Treino renomeado")
    end
  end

  test "editing blocks on a version that is not completed does not enqueue the linker" do
    version = @periodization.versions.create!(trainer: @trainer)
    workout = version.workouts.create!(name: "A", position: 1, blocks: [ exercise("Supino reto", "4x8") ])

    assert_no_enqueued_jobs(only: LinkExercisesJob) do
      workout.update!(blocks: [ exercise("Crucifixo", "3x12") ])
    end
  end

  private
    # A version that has reached `completed` carrying one workout. The workout
    # is built while still pending so creating it doesn't itself stand in for
    # the edit under test.
    def completed_version_with_workout
      version = @periodization.versions.create!(trainer: @trainer, periodization_length_weeks: 8)
      version.workouts.create!(name: "A", position: 1, blocks: [ exercise("Supino reto", "4x8") ])
      version.transition_to!(:generating)
      version.complete!
      version
    end

    def exercise(name, prescription)
      { "kind" => "exercise", "name" => name, "prescription" => prescription }
    end

    def group(label, items)
      { "kind" => "group", "label" => label, "items" => items }
    end

    def item(name, prescription)
      { "name" => name, "prescription" => prescription }
    end

    def freeform(text_md)
      { "kind" => "freeform", "text_md" => text_md }
    end
end
