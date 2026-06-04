require "test_helper"

class ExerciseTest < ActiveSupport::TestCase
  test "an exercise owns its own canonical name as a primary alias" do
    exercise = Exercise.create!(name: "Rosca direta")

    primary = exercise.aliases.find_by(normalized_key: "rosca direta")
    assert primary, "expected a primary alias for the canonical name"
    assert_equal "primary", primary.source
    assert_equal "Rosca direta", primary.raw_name
  end

  test "resolve returns the exercise for case/accent/whitespace variants of an alias" do
    exercise = Exercise.create!(name: "Supino reto")

    assert_equal exercise, Exercise.resolve("  SUPÍNO   reto ")
    assert_equal exercise, Exercise.resolve("supino reto")
  end

  test "resolve returns nil for an unknown name" do
    Exercise.create!(name: "Supino reto")

    assert_nil Exercise.resolve("Movimento que não existe")
  end

  test "resolve returns nil for blank input" do
    assert_nil Exercise.resolve("   ")
    assert_nil Exercise.resolve(nil)
  end

  test "a new exercise defaults to the unenriched state" do
    assert_predicate Exercise.create!(name: "Leg press"), :unenriched?
  end

  test "the unique constraint forbids two aliases sharing a normalized key" do
    Exercise.create!(name: "Leg press") # primary alias key "leg press"
    other = Exercise.create!(name: "Leg press 45")

    dup = other.aliases.build(raw_name: "Leg press", normalized_key: "leg press", source: "llm")
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "exercise_family and muscle_group are optional on mint" do
    exercise = Exercise.create!(name: "Stiff")

    assert_nil exercise.exercise_family
    assert_nil exercise.muscle_group
  end
end
