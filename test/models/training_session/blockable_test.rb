require "test_helper"

class TrainingSession::BlockableTest < ActiveSupport::TestCase
  setup do
    @alice = students(:alice)
    @trainer = users(:one)
  end

  test "mark_block_done! adds the index to progress" do
    session = build_session(blocks_snapshot: three_exercise_blocks)
    session.save!

    session.mark_block_done!("1")

    assert_equal [ "1" ], session.reload.progress
  end

  test "mark_block_done! is idempotent on the same index" do
    session = build_session(blocks_snapshot: three_exercise_blocks)
    session.save!

    session.mark_block_done!("1")
    session.mark_block_done!("1")

    assert_equal [ "1" ], session.reload.progress
  end

  test "mark_block_done! preserves prior completions" do
    session = build_session(blocks_snapshot: three_exercise_blocks)
    session.save!

    session.mark_block_done!("0")
    session.mark_block_done!("2")

    assert_equal [ "0", "2" ], session.reload.progress
  end

  test "unmark_block! removes the index from progress" do
    session = build_session(blocks_snapshot: three_exercise_blocks, progress: [ "0", "1" ])
    session.save!

    session.unmark_block!("0")

    assert_equal [ "1" ], session.reload.progress
  end

  test "unmark_block! is idempotent when the index is absent" do
    session = build_session(blocks_snapshot: three_exercise_blocks, progress: [ "1" ])
    session.save!

    session.unmark_block!("2")

    assert_equal [ "1" ], session.reload.progress
  end

  test "block_completed? returns true when the index is in progress" do
    session = build_session(blocks_snapshot: three_exercise_blocks, progress: [ "2" ])

    assert session.block_completed?("2")
    assert_not session.block_completed?("0")
  end

  test "mark_block_done! raises ArgumentError for non-digit indices" do
    session = build_session(blocks_snapshot: three_exercise_blocks)
    session.save!

    assert_raises(ArgumentError) { session.mark_block_done!("abc") }
    assert_raises(ArgumentError) { session.mark_block_done!("1.0") }
    assert_raises(ArgumentError) { session.mark_block_done!("-1") }
    assert_raises(ArgumentError) { session.mark_block_done!("") }
  end

  test "mark_block_done! raises ArgumentError for indices at or beyond blocks_snapshot.length" do
    session = build_session(blocks_snapshot: three_exercise_blocks)
    session.save!

    assert_raises(ArgumentError) { session.mark_block_done!("3") }
    assert_raises(ArgumentError) { session.mark_block_done!("10") }
  end

  test "unmark_block! raises ArgumentError for malformed indices" do
    session = build_session(blocks_snapshot: three_exercise_blocks, progress: [])
    session.save!

    assert_raises(ArgumentError) { session.unmark_block!("abc") }
    assert_raises(ArgumentError) { session.unmark_block!("1.0") }
  end

  test "unmark_block! raises ArgumentError for out-of-range indices" do
    session = build_session(blocks_snapshot: three_exercise_blocks, progress: [])
    session.save!

    assert_raises(ArgumentError) { session.unmark_block!("3") }
  end

  test "block_completed? raises ArgumentError for malformed indices" do
    session = build_session(blocks_snapshot: three_exercise_blocks)

    assert_raises(ArgumentError) { session.block_completed?("abc") }
  end

  test "model validation rejects progress with non-digit entries on save" do
    session = build_session(blocks_snapshot: three_exercise_blocks, progress: [ "abc" ])

    assert_not session.valid?
    assert_match(/inválido/i, session.errors[:progress].join)
  end

  test "model validation rejects progress with out-of-range entries on save" do
    session = build_session(blocks_snapshot: three_exercise_blocks, progress: [ "5" ])

    assert_not session.valid?
    assert_match(/inválido|range|fora/i, session.errors[:progress].join)
  end

  test "model validation accepts a progress array of valid indices on save" do
    session = build_session(blocks_snapshot: three_exercise_blocks, progress: [ "0", "2" ])

    assert session.valid?, session.errors.full_messages.inspect
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

    def three_exercise_blocks
      [
        { "kind" => "exercise", "name" => "Agachamento", "prescription" => "3x10" },
        { "kind" => "exercise", "name" => "Supino",      "prescription" => "3x8" },
        { "kind" => "exercise", "name" => "Remada",      "prescription" => "3x12" }
      ]
    end
end
