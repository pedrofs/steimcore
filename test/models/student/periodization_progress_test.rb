require "test_helper"

class Student::PeriodizationProgressTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @trainer = users(:one)
  end

  test "target is periodization_length_weeks times weekly_frequency when applicable" do
    student = student_with_plan!(weekly_frequency: 3, length_weeks: 8)

    progress = Student::PeriodizationProgress.new(student)

    assert progress.applicable?
    assert_equal 24, progress.target
  end

  test "not applicable when the student has no active periodization" do
    student = @organization.students.create!(name: "Sem plano", anamnesis_md: "x", weekly_frequency: 3)

    progress = Student::PeriodizationProgress.new(student)

    assert_not progress.applicable?
    assert_nil progress.target
    assert_nil progress.sessions_done
    assert_nil progress.sessions_remaining
    assert_not progress.overdue?
  end

  test "not applicable when weekly_frequency is null" do
    student = student_with_plan!(weekly_frequency: nil, length_weeks: 8)

    assert_not Student::PeriodizationProgress.new(student).applicable?
  end

  test "not applicable when weekly_frequency is zero" do
    student = student_with_plan!(weekly_frequency: 0, length_weeks: 8)

    assert_not Student::PeriodizationProgress.new(student).applicable?
  end

  test "not applicable when the current version is null (never promoted)" do
    student = @organization.students.create!(name: "Gerando", anamnesis_md: "x", weekly_frequency: 3)
    student.start_periodization!(trainer: @trainer) # stays generating, current_version nil

    assert_not Student::PeriodizationProgress.new(student).applicable?
  end

  test "not applicable when the current version has no periodization_length_weeks (legacy data)" do
    student = student_with_plan!(weekly_frequency: 3, length_weeks: 8)
    student.active_periodization.current_version.update_columns(periodization_length_weeks: nil)
    student.reload

    assert_not Student::PeriodizationProgress.new(student).applicable?
  end

  test "sessions_done counts finished sessions on the current version" do
    student = student_with_plan!(weekly_frequency: 1, length_weeks: 8)
    version = student.active_periodization.current_version
    2.times { finish_session_for!(student, version: version) }

    assert_equal 2, Student::PeriodizationProgress.new(student).sessions_done
  end

  test "sessions_done counts finished sessions on superseded versions of the active periodization" do
    student = student_with_plan!(weekly_frequency: 1, length_weeks: 8)
    superseded = student.active_periodization.current_version
    finish_session_for!(student, version: superseded)

    current = complete_and_promote_edit!(student, length_weeks: 8)
    finish_session_for!(student, version: current)

    assert superseded.reload.superseded?
    assert_equal 2, Student::PeriodizationProgress.new(student).sessions_done
  end

  test "sessions_done does not count sessions on an archived periodization" do
    student = student_with_plan!(weekly_frequency: 1, length_weeks: 8)
    archived_version = student.active_periodization.current_version
    finish_session_for!(student, version: archived_version)

    # Starting fresh archives the prior periodization and its sessions' clock.
    new_version = student.start_periodization!(trainer: @trainer)
    new_version.periodization_length_weeks = 8
    new_version.complete!
    student.active_periodization.set_current_version!(new_version)
    student.reload

    assert_equal 0, Student::PeriodizationProgress.new(student).sessions_done
  end

  test "sessions_done does not count unfinished sessions" do
    student = student_with_plan!(weekly_frequency: 1, length_weeks: 8)
    version = student.active_periodization.current_version
    TrainingSession.create!(
      student: student, trainer: @trainer, periodization_version: version,
      workout_name_snapshot: "Treino A", workout_position_snapshot: 1,
      blocks_snapshot: [], progress: []
    ) # active, finished_at nil

    assert_equal 0, Student::PeriodizationProgress.new(student).sessions_done
  end

  test "overdue? is true when sessions_remaining is -1" do
    student = student_with_remaining(-1)

    assert Student::PeriodizationProgress.new(student).overdue?
  end

  test "overdue? is false when sessions_remaining is 0" do
    student = student_with_remaining(0)

    assert_not Student::PeriodizationProgress.new(student).overdue?
  end

  test "overdue? is false when sessions_remaining is 1" do
    student = student_with_remaining(1)

    assert_not Student::PeriodizationProgress.new(student).overdue?
  end

  test "due? is true when sessions_remaining is 0" do
    student = student_with_remaining(0)

    assert Student::PeriodizationProgress.new(student).due?
  end

  test "due? is true when sessions_remaining is 4" do
    student = student_with_remaining(4)

    assert Student::PeriodizationProgress.new(student).due?
  end

  test "due? is false when sessions_remaining is 5" do
    student = student_with_remaining(5)

    assert_not Student::PeriodizationProgress.new(student).due?
  end

  test "due? is false when sessions_remaining is -1 (overdue, not due)" do
    student = student_with_remaining(-1)

    assert_not Student::PeriodizationProgress.new(student).due?
  end

  test "due? is false when not applicable" do
    student = @organization.students.create!(name: "Sem plano", anamnesis_md: "x", weekly_frequency: 3)

    assert_not Student::PeriodizationProgress.new(student).due?
  end

  test "due? and overdue? are mutually exclusive across boundary states" do
    [ -1, 0, 1, 4, 5 ].each do |remaining|
      progress = Student::PeriodizationProgress.new(student_with_remaining(remaining))

      assert_not (progress.due? && progress.overdue?),
                 "due? and overdue? both true at sessions_remaining=#{remaining}"
    end
  end

  private
    # Builds an unarchived student with a completed, promoted current version
    # carrying periodization_length_weeks, so PeriodizationProgress is applicable.
    def student_with_plan!(weekly_frequency:, length_weeks:)
      student = @organization.students.create!(
        name: "Aluno #{SecureRandom.hex(3)}",
        anamnesis_md: "x",
        weekly_frequency: weekly_frequency
      )
      version = student.start_periodization!(trainer: @trainer)
      version.periodization_length_weeks = length_weeks
      version.complete!
      student.active_periodization.set_current_version!(version)
      student.reload
    end

    # weekly_frequency=1, length=8 → target 8, so sessions_done = target - remaining
    # stays non-negative for every remaining we exercise (incl. the 5 boundary).
    def student_with_remaining(remaining)
      student = student_with_plan!(weekly_frequency: 1, length_weeks: 8)
      version = student.active_periodization.current_version
      (8 - remaining).times { finish_session_for!(student, version: version) }
      student
    end

    # Forks the current version, completes and promotes it, returning the new
    # current version. The prior current version becomes superseded.
    def complete_and_promote_edit!(student, length_weeks:)
      version = student.active_periodization.start_edit!(scope: :periodization, trainer: @trainer)
      version.periodization_length_weeks = length_weeks
      version.complete!
      student.active_periodization.set_current_version!(version)
      student.reload
      version
    end

    def finish_session_for!(student, version:)
      session = TrainingSession.create!(
        student: student,
        trainer: @trainer,
        periodization_version: version,
        workout_name_snapshot: "Treino A",
        workout_position_snapshot: 1,
        blocks_snapshot: [],
        progress: []
      )
      session.update_columns(finished_at: Time.current)
      session
    end
end
