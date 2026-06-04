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

  private
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
