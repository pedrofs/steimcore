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

  test "enrich attaches media and flips the exercise to enriched" do
    exercise = Exercise.create!(name: "Supino reto")

    exercise.enrich(media: [ { io: StringIO.new("png"), filename: "a.png", content_type: "image/png" } ])

    assert_predicate exercise.reload, :enriched?
    assert exercise.media.attached?
  end

  test "enrich without media stores taxonomy but leaves the exercise unenriched" do
    family = Exercise::Family.create!(name: "Supino", normalized_key: "supino")
    muscle = Exercise::MuscleGroup.create!(name: "Peito", normalized_key: "peito")
    exercise = Exercise.create!(name: "Supino reto")

    exercise.enrich(exercise_family: family, muscle_group: muscle)

    assert_predicate exercise.reload, :unenriched?
    assert_equal family, exercise.exercise_family
    assert_equal muscle, exercise.muscle_group
  end

  test "enrich keeps an already-enriched exercise enriched when only taxonomy changes" do
    exercise = Exercise.create!(name: "Supino reto")
    exercise.enrich(media: [ { io: StringIO.new("png"), filename: "a.png", content_type: "image/png" } ])

    exercise.enrich(exercise_family: Exercise::Family.for_name("Supino"))

    assert_predicate exercise.reload, :enriched?
    assert_equal "Supino", exercise.exercise_family.name
  end

  test "merge_into! repoints the loser's aliases onto the target and records merged_into" do
    survivor = Exercise.create!(name: "Supino reto")
    loser = Exercise.create!(name: "Supino reto com barra")
    loser.aliases.create!(raw_name: "supino barra", normalized_key: "supino barra", source: "llm")

    loser.merge_into!(survivor)

    assert_equal survivor, loser.reload.merged_into
    assert_empty loser.aliases.reload
    repointed = survivor.aliases.reload.map(&:normalized_key)
    assert_includes repointed, "supino reto com barra"
    assert_includes repointed, "supino barra"
  end

  test "after merge_into! names that resolved to the loser resolve to the survivor" do
    survivor = Exercise.create!(name: "Supino reto")
    loser = Exercise.create!(name: "Supino reto com barra")

    loser.merge_into!(survivor)

    assert_equal survivor, Exercise.resolve("Supino reto com barra")
    assert_equal survivor, Exercise.resolve("supíno reto") # survivor's own name still resolves
  end

  test "merge_into! preserves the alias unique key — no duplicate-key violation" do
    survivor = Exercise.create!(name: "Supino reto")
    loser = Exercise.create!(name: "Supino inclinado")

    assert_nothing_raised { loser.merge_into!(survivor) }
    keys = survivor.aliases.reload.map(&:normalized_key)
    assert_equal keys.uniq, keys
  end

  test "merge_into! refuses to merge an exercise into itself" do
    exercise = Exercise.create!(name: "Supino reto")

    assert_raises(ArgumentError) { exercise.merge_into!(exercise) }
    assert_nil exercise.reload.merged_into
  end

  test "merge_into! flattens chains — merging the survivor again repoints inherited aliases" do
    a = Exercise.create!(name: "Supino reto")
    b = Exercise.create!(name: "Supino reto com barra")
    c = Exercise.create!(name: "Supino")

    b.merge_into!(a)
    a.merge_into!(c)

    assert_equal c, Exercise.resolve("Supino reto com barra")
    assert_equal c, Exercise.resolve("Supino reto")
  end
end
