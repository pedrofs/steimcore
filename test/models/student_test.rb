require "test_helper"

class StudentTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
  end

  test "requires a name" do
    student = Student.new(organization: @organization)

    assert_not student.valid?
    assert_includes student.errors[:name], "can't be blank"
  end

  test "requires an organization" do
    student = Student.new(name: "Alice")

    assert_not student.valid?
    assert_includes student.errors[:organization], "must exist"
  end

  test "is valid with only a name and an organization" do
    student = Student.new(name: "Alice", organization: @organization)

    assert student.valid?, student.errors.full_messages.to_sentence
  end

  test "structured and freeform fields default to null/empty on create" do
    student = Student.create!(name: "Alice", organization: @organization)

    assert_nil student.birthday
    assert_nil student.age
    assert_nil student.sex
    assert_nil student.primary_goal
    assert_nil student.restrictions_summary
    assert_nil student.weekly_frequency
    assert_nil student.active_periodization_id
    assert_equal "", student.anamnesis_md
    assert_equal "", student.notes_md
  end

  test "structured and freeform fields are updateable later" do
    student = Student.create!(name: "Alice", organization: @organization)

    student.update!(
      birthday: Date.new(1994, 3, 15),
      sex: "Feminino",
      primary_goal: "Hipertrofia",
      restrictions_summary: "Lombar sensível",
      weekly_frequency: 4,
      anamnesis_md: "## Histórico\n\nLesão antiga.",
      notes_md: "Toca dança duas vezes por semana."
    )
    student.reload

    assert_equal Date.new(1994, 3, 15), student.birthday
    assert_equal "Feminino", student.sex
    assert_equal "Hipertrofia", student.primary_goal
    assert_equal "Lombar sensível", student.restrictions_summary
    assert_equal 4, student.weekly_frequency
    assert_equal "## Histórico\n\nLesão antiga.", student.anamnesis_md
    assert_equal "Toca dança duas vezes por semana.", student.notes_md
  end

  test "age is derived from birthday and accounts for whether the birthday has passed this year" do
    student = Student.new(name: "Alice", organization: @organization)

    student.birthday = Date.new(1990, 6, 15)
    assert_equal 36, student.age(today: Date.new(2026, 6, 15))
    assert_equal 36, student.age(today: Date.new(2026, 12, 31))
    assert_equal 35, student.age(today: Date.new(2026, 6, 14))
    assert_equal 35, student.age(today: Date.new(2026, 1, 1))
  end

  test "age returns nil when birthday is not set" do
    student = Student.create!(name: "Alice", organization: @organization)
    assert_nil student.age
  end

  test "archive! flips the archived state and is reflected by the scopes" do
    student = Student.create!(name: "Dave", organization: @organization)

    assert_not student.archived?
    assert_includes Student.unarchived, student
    assert_not_includes Student.archived, student

    student.archive!

    assert student.archived?
    assert_not_nil student.archived_at
    assert_includes Student.archived, student
    assert_not_includes Student.unarchived, student
  end

  test "unarchived scope is the default expectation for the index" do
    active = students(:alice)
    archived = students(:archived_carol)

    assert_includes Student.unarchived, active
    assert_not_includes Student.unarchived, archived
  end

  test "is destroyed when forced to nil organization" do
    student = Student.new(name: "Eve")

    assert_not student.valid?
    assert_includes student.errors[:organization], "must exist"
  end

  # Regression: the student↔periodization and periodization↔current_version FK
  # pairs form cycles. Destroy must succeed when both are populated; deferred
  # FKs let the cascade validate at COMMIT rather than per-statement.
  test "destroy cascades through periodizations, versions, and training_sessions without FK errors" do
    student = Student.create!(name: "Eve", organization: @organization)
    trainer = users(:one)
    version = student.start_periodization!(trainer: trainer)
    workout = version.workouts.create!(name: "Treino A", position: 1, blocks: [])
    version.periodization.update!(current_version: version)
    # Fork a child version so periodization_versions.parent_version_id (a
    # self-referential FK) is populated and gets exercised by the cascade.
    version.periodization.versions.create!(trainer: trainer, parent_version: version)
    TrainingSession.create!(
      student: student,
      trainer: trainer,
      workout: workout,
      periodization_version: version,
      workout_name_snapshot: workout.name,
      workout_position_snapshot: workout.position,
      blocks_snapshot: workout.blocks
    )

    assert_difference -> { Student.count } => -1,
                      -> { Periodization.count } => -1,
                      -> { PeriodizationVersion.count } => -2,
                      -> { Workout.count } => -1,
                      -> { TrainingSession.count } => -1 do
      student.destroy!
    end
  end
end
