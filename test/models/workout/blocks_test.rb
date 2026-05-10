require "test_helper"

class Workout::BlocksTest < ActiveSupport::TestCase
  # --- happy paths ---

  test "empty array is valid" do
    assert_equal [], Workout::Blocks.errors_for([])
  end

  test "exercise block with required fields is valid" do
    blocks = [
      { "kind" => "exercise", "name" => "Supino reto", "prescription" => "3 × 8-10" }
    ]
    assert_equal [], Workout::Blocks.errors_for(blocks)
  end

  test "exercise block accepts optional rest_s and notes" do
    blocks = [
      {
        "kind" => "exercise",
        "name" => "Supino",
        "prescription" => "3 × 8",
        "rest_s" => 90,
        "notes" => "tempo 3-0-1"
      }
    ]
    assert_equal [], Workout::Blocks.errors_for(blocks)
  end

  test "group block with valid items is valid" do
    blocks = [
      {
        "kind" => "group",
        "label" => "Superset A",
        "rounds" => 3,
        "items" => [
          { "name" => "Rosca direta", "prescription" => "10 reps" },
          { "name" => "Tríceps testa", "prescription" => "10 reps" }
        ]
      }
    ]
    assert_equal [], Workout::Blocks.errors_for(blocks)
  end

  test "freeform block with text_md is valid" do
    blocks = [
      { "kind" => "freeform", "text_md" => "Aquecimento livre 5-10 min" }
    ]
    assert_equal [], Workout::Blocks.errors_for(blocks)
  end

  test "mixed block kinds in a single workout are valid" do
    blocks = [
      { "kind" => "freeform", "text_md" => "Aquecimento" },
      { "kind" => "exercise", "name" => "Agachamento", "prescription" => "5x5" },
      {
        "kind" => "group",
        "items" => [
          { "name" => "X", "prescription" => "8" },
          { "name" => "Y", "prescription" => "8" }
        ]
      }
    ]
    assert_equal [], Workout::Blocks.errors_for(blocks)
  end

  test "accepts symbol keys for keys and values" do
    blocks = [
      { kind: "exercise", name: "X", prescription: "3x5" }
    ]
    assert_equal [], Workout::Blocks.errors_for(blocks)
  end

  # --- malformed shapes ---

  test "blocks must be an array" do
    errors = Workout::Blocks.errors_for("not-an-array")
    assert_includes errors, "blocos devem ser uma lista"
  end

  test "blocks must be an array even if nil" do
    errors = Workout::Blocks.errors_for(nil)
    assert_includes errors, "blocos devem ser uma lista"
  end

  test "each block must be a hash" do
    errors = Workout::Blocks.errors_for([ "string" ])
    assert(errors.any? { |e| e.include?("bloco 0") }, "expected error about bloco 0, got: #{errors.inspect}")
  end

  test "block missing kind is rejected" do
    errors = Workout::Blocks.errors_for([ { "name" => "x" } ])
    assert(errors.any? { |e| e.include?("kind") }, "expected error about kind, got: #{errors.inspect}")
  end

  test "block with unknown kind is rejected" do
    errors = Workout::Blocks.errors_for([ { "kind" => "mystery" } ])
    assert(errors.any? { |e| e.include?("mystery") || e.include?("kind") })
  end

  test "exercise block missing name is rejected" do
    errors = Workout::Blocks.errors_for([
      { "kind" => "exercise", "prescription" => "3x5" }
    ])
    assert(errors.any? { |e| e.include?("name") })
  end

  test "exercise block missing prescription is rejected" do
    errors = Workout::Blocks.errors_for([
      { "kind" => "exercise", "name" => "X" }
    ])
    assert(errors.any? { |e| e.include?("prescription") })
  end

  test "group block missing items is rejected" do
    errors = Workout::Blocks.errors_for([
      { "kind" => "group", "label" => "G" }
    ])
    assert(errors.any? { |e| e.include?("items") })
  end

  test "group block with non-array items is rejected" do
    errors = Workout::Blocks.errors_for([
      { "kind" => "group", "items" => "not array" }
    ])
    assert(errors.any? { |e| e.include?("items") })
  end

  test "group items missing name or prescription are rejected" do
    errors = Workout::Blocks.errors_for([
      { "kind" => "group", "items" => [ { "name" => "X" } ] }
    ])
    assert(errors.any? { |e| e.include?("prescription") })
  end

  test "freeform block missing text_md is rejected" do
    errors = Workout::Blocks.errors_for([ { "kind" => "freeform" } ])
    assert(errors.any? { |e| e.include?("text_md") })
  end

  test "freeform block with non-string text_md is rejected" do
    errors = Workout::Blocks.errors_for([
      { "kind" => "freeform", "text_md" => 42 }
    ])
    assert(errors.any? { |e| e.include?("text_md") })
  end

  # --- model integration ---

  test "Workout#valid? is false when blocks are malformed" do
    organization = organizations(:steimfit)
    student = students(:alice)
    trainer = users(:one)
    periodization = student.periodizations.create!
    version = periodization.versions.create!(trainer: trainer, voice_recording: nil, parent_version: nil)

    workout = Workout.new(
      periodization_version: version,
      name: "A",
      position: 1,
      blocks: [ { "kind" => "unknown" } ]
    )

    assert_not workout.valid?
    assert workout.errors[:blocks].any?, "expected validation errors on :blocks"
  end

  test "Workout#valid? is true for an exercise block" do
    organization = organizations(:steimfit)
    student = students(:alice)
    trainer = users(:one)
    periodization = student.periodizations.create!
    version = periodization.versions.create!(trainer: trainer, voice_recording: nil, parent_version: nil)

    workout = Workout.new(
      periodization_version: version,
      name: "A",
      position: 1,
      blocks: [ { "kind" => "exercise", "name" => "Supino", "prescription" => "3x8" } ]
    )

    assert workout.valid?, "expected valid; got #{workout.errors.full_messages.inspect}"
  end
end
