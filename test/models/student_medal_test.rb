require "test_helper"

class StudentMedalTest < ActiveSupport::TestCase
  setup do
    @student = students(:alice)
  end

  test "requires family, tier, and value_snapshot" do
    medal = StudentMedal.new(student: @student)

    assert_not medal.valid?
    assert_includes medal.errors[:family], "can't be blank"
    assert_includes medal.errors[:tier], "can't be blank"
    assert_includes medal.errors[:value_snapshot], "can't be blank"
  end

  test "tier is unique per student and family" do
    @student.student_medals.create!(family: "workouts", tier: 1, value_snapshot: 1, earned_at: Time.current)

    duplicate = @student.student_medals.build(family: "workouts", tier: 1, value_snapshot: 3, earned_at: Time.current)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tier], "has already been taken"
  end

  test "the same tier in different families is allowed" do
    @student.student_medals.create!(family: "workouts", tier: 1, value_snapshot: 1, earned_at: Time.current)

    other = @student.student_medals.build(family: "full_weeks", tier: 1, value_snapshot: 1, earned_at: Time.current)

    assert other.valid?, other.errors.full_messages.inspect
  end

  test "the unique index backstops the validation" do
    @student.student_medals.create!(family: "workouts", tier: 1, value_snapshot: 1, earned_at: Time.current)

    duplicate = @student.student_medals.build(family: "workouts", tier: 1, value_snapshot: 9, earned_at: Time.current)

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
