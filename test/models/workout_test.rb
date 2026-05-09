require "test_helper"

class WorkoutTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
    periodization = @student.periodizations.create!
    @version = periodization.versions.create!(
      trainer: @trainer,
      voice_recording: nil,
      parent_version: nil
    )
  end

  test "requires a name and a position" do
    workout = Workout.new(periodization_version: @version)

    assert_not workout.valid?
    assert_includes workout.errors[:name], "can't be blank"
    assert_includes workout.errors[:position], "can't be blank"
  end

  test "default scope orders by position" do
    @version.workouts.create!(name: "B", position: 2, content_md: "")
    @version.workouts.create!(name: "A", position: 1, content_md: "")
    @version.workouts.create!(name: "C", position: 3, content_md: "")

    assert_equal %w[A B C], @version.workouts.pluck(:name)
  end
end
