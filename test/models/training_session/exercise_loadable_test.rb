require "test_helper"

class TrainingSession::ExerciseLoadableTest < ActiveSupport::TestCase
  setup do
    @alice = students(:alice)
    @trainer = users(:one)
  end

  test "record_load! creates a load for the student, scoped to the session" do
    session = build_session(blocks_snapshot: blocks)
    session.save!

    load = session.record_load!(exercise_name: "Supino Reto", value: "60kg")

    assert_equal @alice, load.student
    assert_equal session, load.training_session
    assert_equal "60kg", load.value
    assert_equal "supino reto", load.exercise_key
  end

  test "blocks_with_loads injects the current weight per exercise and group item" do
    session = build_session(blocks_snapshot: blocks)
    session.save!
    session.record_load!(exercise_name: "Supino Reto", value: "60kg")
    session.record_load!(exercise_name: "Rosca", value: "12kg")

    enriched = session.blocks_with_loads

    assert_equal "60kg", enriched[0]["weight"]
    assert_nil enriched[1]["weight"], "exercise without a recorded load has nil weight"
    assert_equal "12kg", enriched[2]["items"][0]["weight"]
    assert_nil enriched[2]["items"][1]["weight"]
    assert_equal "freeform", enriched[3]["kind"]
    assert_not enriched[3].key?("weight"), "freeform blocks are untouched"
  end

  test "blocks_with_loads reflects the most recent value per movement" do
    session = build_session(blocks_snapshot: blocks)
    session.save!
    session.record_load!(exercise_name: "Supino Reto", value: "60kg")
    session.record_load!(exercise_name: "supíno  reto", value: "65kg")

    assert_equal "65kg", session.blocks_with_loads[0]["weight"]
    assert_equal 1, @alice.current_loads.size, "name variants collapse to one key"
  end

  private
    def build_session(**overrides)
      defaults = {
        student: @alice,
        trainer: @trainer,
        workout_name_snapshot: "Treino",
        workout_position_snapshot: 1,
        blocks_snapshot: [],
        progress: []
      }
      TrainingSession.new(defaults.merge(overrides))
    end

    def blocks
      [
        { "kind" => "exercise", "name" => "Supino Reto",  "prescription" => "4x10" },
        { "kind" => "exercise", "name" => "Agachamento",  "prescription" => "4x8" },
        { "kind" => "group", "label" => "Bíceps", "items" => [
          { "name" => "Rosca",   "prescription" => "3x12" },
          { "name" => "Martelo", "prescription" => "3x12" }
        ] },
        { "kind" => "freeform", "text_md" => "Alongar" }
      ]
    end
end
