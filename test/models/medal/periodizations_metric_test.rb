require "test_helper"

# Edges of the `periodizations` Medal family metric (slice 3, parent #145,
# ADR-0005). The metric counts Completed periodizations — blocks trained to
# Sessions remaining <= 0 — reusing Student::PeriodizationProgress (ADR-0002),
# counting active + archived, and staying locked without an explicit cadence.
class Medal::PeriodizationsMetricTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @trainer = users(:one)
    @family = Medal.find("periodizations")
  end

  test "locked (nil) without an explicit weekly_frequency — no fallback" do
    student = @organization.students.create!(name: "Sem cadência", anamnesis_md: "x", weekly_frequency: nil)
    build_completed_block!(student, length_weeks: 8, finished_sessions: 8)
    student.update_columns(weekly_frequency: nil)

    assert_nil @family.metric(student.reload)

    student.update_columns(weekly_frequency: 0)
    assert_nil @family.metric(student.reload)
  end

  test "counts a block trained to the exact dose (Sessions remaining = 0)" do
    student = new_student(weekly_frequency: 1)
    build_completed_block!(student, length_weeks: 8, finished_sessions: 8) # target 8, remaining 0

    assert_equal 1, @family.metric(student.reload)
  end

  test "excludes a block one session short of the dose (Sessions remaining > 0)" do
    student = new_student(weekly_frequency: 1)
    build_completed_block!(student, length_weeks: 8, finished_sessions: 7) # remaining 1

    assert_equal 0, @family.metric(student.reload)
  end

  test "excludes a block whose current version carries no periodization_length_weeks" do
    student = new_student(weekly_frequency: 1)
    block = build_completed_block!(student, length_weeks: 8, finished_sessions: 8)
    block.current_version.update_columns(periodization_length_weeks: nil)

    assert_equal 0, @family.metric(student.reload)
  end

  test "counts both the active block and archived ones" do
    student = new_student(weekly_frequency: 1)
    build_completed_block!(student, length_weeks: 8, finished_sessions: 8) # archived by the next start
    build_completed_block!(student, length_weeks: 8, finished_sessions: 8) # active

    archived = student.periodizations.archived.count
    assert_equal 1, archived, "first block should have been archived by the second start_periodization!"
    assert_equal 2, @family.metric(student.reload)
  end

  test "an early-archived block is excluded while a completed active block still counts" do
    student = new_student(weekly_frequency: 1)
    build_completed_block!(student, length_weeks: 8, finished_sessions: 3) # remaining 5, then archived
    build_completed_block!(student, length_weeks: 8, finished_sessions: 8) # active, remaining 0

    assert_equal 1, @family.metric(student.reload)
  end

  private
    def new_student(weekly_frequency:)
      @organization.students.create!(
        name: "Aluno #{SecureRandom.hex(3)}", anamnesis_md: "x", weekly_frequency: weekly_frequency
      )
    end

    # Starts a fresh periodization (archiving any prior active block), promotes a
    # completed current version carrying length_weeks, and logs finished sessions
    # against it. Returns the periodization.
    def build_completed_block!(student, length_weeks:, finished_sessions:)
      version = student.start_periodization!(trainer: @trainer)
      version.periodization_length_weeks = length_weeks
      version.complete!
      student.active_periodization.set_current_version!(version)
      finished_sessions.times { finish_session_for!(student, version: version) }
      student.active_periodization
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
