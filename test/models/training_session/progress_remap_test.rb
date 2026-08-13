require "test_helper"

class TrainingSession::ProgressRemapTest < ActiveSupport::TestCase
  test "identity mapping leaves progress untouched" do
    assert_equal [ "0", "2" ], remap([ "0", "2" ], [ 0, 1, 2 ])
  end

  test "reorder moves each done mark to its block's new position" do
    # blocks [A, B, C] reordered to [C, A, B]: A moves to 1, C moves to 0
    assert_equal [ "0", "1" ], remap([ "0", "2" ], [ 2, 0, 1 ])
  end

  test "rename in place preserves the done mark" do
    # block 1 was renamed, so it still originates from index 1
    assert_equal [ "1" ], remap([ "1" ], [ 0, 1, 2 ])
  end

  test "removing a completed block drops it from progress" do
    # blocks [A, B, C]; B (index 1) removed
    assert_equal [ "1" ], remap([ "1", "2" ], [ 0, 2 ])
  end

  test "removing an uncompleted block keeps the other marks" do
    # blocks [A, B, C]; C (index 2, undone) removed
    assert_equal [ "0", "1" ], remap([ "0", "1" ], [ 0, 1 ])
  end

  test "insertion at the end leaves existing marks in place" do
    assert_equal [ "0" ], remap([ "0" ], [ 0, 1, nil ])
  end

  test "insertion in the middle shifts later marks" do
    assert_equal [ "0", "2" ], remap([ "0", "1" ], [ 0, nil, 1 ])
  end

  test "newly added blocks are never marked done" do
    assert_equal [], remap([ "0", "1" ], [ nil, nil, nil ])
  end

  test "empty progress stays empty" do
    assert_equal [], remap([], [ 0, 1, 2 ])
  end

  test "progress referencing every block survives a full reorder" do
    assert_equal [ "0", "1", "2" ], remap([ "0", "1", "2" ], [ 2, 1, 0 ])
  end

  test "duplicate entries in progress collapse to one" do
    assert_equal [ "1" ], remap([ "1", "1" ], [ 0, 1 ])
  end

  test "a duplicated origin index awards the mark to the earliest copy" do
    assert_equal [ "0" ], remap([ "1" ], [ 1, 1 ])
  end

  test "output is ordered ascending regardless of input order" do
    assert_equal [ "0", "1", "2" ], remap([ "2", "0", "1" ], [ 0, 1, 2 ])
  end

  test "an empty blocks array drops every mark" do
    assert_equal [], remap([ "0", "1" ], [])
  end

  test "integer origin indices and string progress entries interoperate" do
    assert_equal [ "0" ], remap([ "1" ], [ "1", "0" ])
  end

  test "non-numeric progress entries are discarded" do
    assert_equal [ "0" ], remap([ "0", "abc", "" ], [ 0, 1 ])
  end

  private
    def remap(progress, origin_indices)
      TrainingSession::ProgressRemap.remap(progress: progress, origin_indices: origin_indices)
    end
end
