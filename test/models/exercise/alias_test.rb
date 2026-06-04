require "test_helper"

class Exercise::AliasTest < ActiveSupport::TestCase
  test "candidates_for surfaces an exercise for an equipment variant of its alias" do
    Exercise.create!(name: "Supino reto")
    Exercise.create!(name: "Agachamento livre")

    names = Exercise::Alias.candidates_for("Supino reto com barra", limit: 5).map(&:name)

    assert_includes names, "Supino reto"
  end

  test "candidates_for surfaces an exercise for a typo of its alias" do
    Exercise.create!(name: "Levantamento terra")

    names = Exercise::Alias.candidates_for("Levantamento tera").map(&:name)

    assert_includes names, "Levantamento terra"
  end

  test "candidates_for includes an exact normalized match among the candidates" do
    leg = Exercise.create!(name: "Leg press")

    ids = Exercise::Alias.candidates_for("  LEG   press ").map(&:id)

    assert_includes ids, leg.id
  end

  test "candidates_for returns nothing for a name with no lexical overlap" do
    Exercise.create!(name: "Supino reto")

    assert_empty Exercise::Alias.candidates_for("xyzzy plughwobble")
  end

  test "candidates_for searches the whole alias corpus, not only canonical names" do
    exercise = Exercise.create!(name: "Rosca direta")
    exercise.aliases.create!(
      raw_name: "Rosca bíceps barra",
      normalized_key: Exercise.normalize_name("Rosca bíceps barra"),
      source: "llm"
    )
    Exercise.create!(name: "Tríceps na corda")

    names = Exercise::Alias.candidates_for("rosca biceps com barra", limit: 5).map(&:name)

    assert_includes names, "Rosca direta"
  end

  test "candidates_for orders by similarity and respects the limit" do
    Exercise.create!(name: "Supino reto")
    Exercise.create!(name: "Supino inclinado")
    Exercise.create!(name: "Agachamento")

    top = Exercise::Alias.candidates_for("Supino reto", limit: 1)

    assert_equal 1, top.length
    assert_equal "Supino reto", top.first.name
  end

  test "candidates_for returns each exercise once even with several matching aliases" do
    exercise = Exercise.create!(name: "Supino reto")
    exercise.aliases.create!(
      raw_name: "Supino reto com barra",
      normalized_key: Exercise.normalize_name("Supino reto com barra"),
      source: "llm"
    )

    ids = Exercise::Alias.candidates_for("Supino reto com barra").map(&:id)

    assert_equal ids.uniq, ids
  end

  test "candidates_for returns empty for blank input" do
    Exercise.create!(name: "Supino reto")

    assert_empty Exercise::Alias.candidates_for("   ")
    assert_empty Exercise::Alias.candidates_for(nil)
  end
end
