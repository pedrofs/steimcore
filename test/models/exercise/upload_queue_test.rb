require "test_helper"

class Exercise::UploadQueueTest < ActiveSupport::TestCase
  setup do
    @student = students(:alice)
    @trainer = users(:one)
    periodization = @student.periodizations.create!
    @version = periodization.versions.create!(trainer: @trainer, parent_version: nil)
    @position = 0
  end

  test "ranks unenriched exercises by total references across all workouts, desc then name" do
    light = Exercise.create!(name: "Stiff")
    heavy = Exercise.create!(name: "Supino reto")
    create_workout(exercise_block("Supino reto"), exercise_block("Stiff"))
    create_workout(exercise_block("Supino reto"), exercise_block("Supino reto"))

    assert_equal [ [ heavy, 3 ], [ light, 1 ] ], Exercise.upload_queue
  end

  test "counts repeated references within a single workout (total references)" do
    exercise = Exercise.create!(name: "Supino reto")
    create_workout(exercise_block("Supino reto"), exercise_block("Supino reto"))

    assert_equal [ [ exercise, 2 ] ], Exercise.upload_queue
  end

  test "counts names nested inside group items" do
    voador = Exercise.create!(name: "Voador")
    create_workout(group_block("Voador", "Voador"))

    assert_equal [ [ voador, 2 ] ], Exercise.upload_queue
  end

  test "attributes references to the exercise across all its alias variants" do
    exercise = Exercise.create!(name: "Supino reto")
    exercise.aliases.create!(raw_name: "Supino com barra", normalized_key: "supino com barra", source: "llm")
    create_workout(exercise_block("Supino reto"), exercise_block("Supino com barra"))

    assert_equal [ [ exercise, 2 ] ], Exercise.upload_queue
  end

  test "excludes enriched exercises even when workouts reference them" do
    enriched = Exercise.create!(name: "Supino reto")
    enriched.update!(state: :enriched)
    create_workout(exercise_block("Supino reto"))

    assert_empty Exercise.upload_queue
  end

  test "excludes merged-away exercises" do
    survivor = Exercise.create!(name: "Supino")
    merged = Exercise.create!(name: "Supino reto")
    merged.update!(merged_into: survivor)
    create_workout(exercise_block("Supino reto"))

    assert_not_includes Exercise.upload_queue.map(&:first), merged
  end

  test "excludes unenriched exercises that no workout references" do
    Exercise.create!(name: "Exercício órfão")

    assert_empty Exercise.upload_queue
  end

  test "ignores freeform blocks and is empty when there are no workouts" do
    Exercise.create!(name: "Supino reto")

    assert_empty Exercise.upload_queue
  end

  private
    def create_workout(*blocks)
      @position += 1
      @version.workouts.create!(name: "Treino #{@position}", position: @position, blocks: blocks)
    end

    def exercise_block(name)
      { "kind" => "exercise", "name" => name, "prescription" => "4x8" }
    end

    def group_block(*names)
      { "kind" => "group", "items" => names.map { |name| { "name" => name, "prescription" => "8 reps" } } }
    end
end
