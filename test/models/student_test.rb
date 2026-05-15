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

  test "anamnesis_pending matches unarchived students with blank anamnesis_md" do
    @organization.students.destroy_all
    empty = @organization.students.create!(name: "Sem anamnese") # default "" anamnesis_md
    whitespace = @organization.students.create!(name: "Espaços", anamnesis_md: "   \n\t ")
    filled = @organization.students.create!(name: "Com anamnese", anamnesis_md: "## Histórico\n\nLesão.")
    archived = @organization.students.create!(name: "Arquivado", archived_at: 1.day.ago)

    pending = Student.anamnesis_pending

    assert_includes pending, empty
    assert_includes pending, whitespace
    assert_not_includes pending, filled
    assert_not_includes pending, archived
  end

  test "plan_needs_action matches when the active periodization has a failed version" do
    @organization.students.destroy_all
    trainer = users(:one)
    student = @organization.students.create!(name: "Falhou", anamnesis_md: "x")
    version = student.start_periodization!(trainer: trainer)
    version.fail!("boom")

    assert_includes Student.plan_needs_action, student
  end

  test "plan_needs_action matches when the active periodization has a completed unpromoted, non-superseded version" do
    @organization.students.destroy_all
    trainer = users(:one)
    student = @organization.students.create!(name: "Rascunho", anamnesis_md: "x")
    version = student.start_periodization!(trainer: trainer)
    version.complete!
    # Not promoted: periodization.current_version_id is still nil.

    assert_nil student.active_periodization.current_version_id
    assert_includes Student.plan_needs_action, student
  end

  test "plan_needs_action does NOT match when the candidate completed version has been superseded by a child fork" do
    @organization.students.destroy_all
    trainer = users(:one)
    student = @organization.students.create!(name: "Histórico", anamnesis_md: "x")
    version = student.start_periodization!(trainer: trainer)
    version.complete!
    # A child fork supersedes the version even before promotion.
    student.active_periodization.versions.create!(trainer: trainer, parent_version: version)

    assert_not_includes Student.plan_needs_action, student
  end

  test "plan_needs_action does NOT match when the only completed version is the promoted current_version" do
    @organization.students.destroy_all
    trainer = users(:one)
    student = @organization.students.create!(name: "Promovido", anamnesis_md: "x")
    version = student.start_periodization!(trainer: trainer)
    version.complete!
    student.active_periodization.set_current_version!(version)

    assert_not_includes Student.plan_needs_action, student
  end

  test "plan_needs_action does NOT match when the only version is still generating" do
    @organization.students.destroy_all
    trainer = users(:one)
    student = @organization.students.create!(name: "Gerando", anamnesis_md: "x")
    student.start_periodization!(trainer: trainer) # stays :generating

    assert_not_includes Student.plan_needs_action, student
  end

  test "plan_needs_action does NOT match a student without an active periodization, even if archived periodizations have failed versions" do
    @organization.students.destroy_all
    trainer = users(:one)
    student = @organization.students.create!(name: "Sem plano", anamnesis_md: "x")
    version = student.start_periodization!(trainer: trainer)
    version.fail!("oops")
    # Archive the periodization and clear the active pointer to mimic a reset.
    student.update!(active_periodization: nil)
    version.periodization.archive!

    assert_not_includes Student.plan_needs_action, student
  end

  test "plan_needs_action excludes archived students" do
    @organization.students.destroy_all
    trainer = users(:one)
    student = @organization.students.create!(name: "Arquivado", anamnesis_md: "x")
    version = student.start_periodization!(trainer: trainer)
    version.fail!("oops")
    student.archive!

    assert_not_includes Student.plan_needs_action, student
  end

  # The inactive scope uses today's wall clock against periodization/session
  # timestamps, so a fixed "now" is needed for the cutoff matrix to be
  # reproducible across runs.
  INACTIVE_NOW = Time.zone.local(2026, 5, 15, 10, 0, 0)

  test "inactive matches a student with weekly_frequency=1 and last session 15 days ago (cutoff 14d)" do
    travel_to INACTIVE_NOW do
      student = build_student_with_completed_plan!(weekly_frequency: 1, plan_created_at: 30.days.ago)
      finish_session_for!(student, at: 15.days.ago)

      assert_includes Student.inactive, student
    end
  end

  test "inactive does NOT match a student with weekly_frequency=1 and last session 10 days ago (cutoff 14d)" do
    travel_to INACTIVE_NOW do
      student = build_student_with_completed_plan!(weekly_frequency: 1, plan_created_at: 30.days.ago)
      finish_session_for!(student, at: 10.days.ago)

      assert_not_includes Student.inactive, student
    end
  end

  test "inactive matches a student with weekly_frequency=3 and last session 6 days ago (cutoff 5d)" do
    travel_to INACTIVE_NOW do
      student = build_student_with_completed_plan!(weekly_frequency: 3, plan_created_at: 30.days.ago)
      finish_session_for!(student, at: 6.days.ago)

      assert_includes Student.inactive, student
    end
  end

  test "inactive does NOT match a student with weekly_frequency=3 and last session 4 days ago (cutoff 5d)" do
    travel_to INACTIVE_NOW do
      student = build_student_with_completed_plan!(weekly_frequency: 3, plan_created_at: 30.days.ago)
      finish_session_for!(student, at: 4.days.ago)

      assert_not_includes Student.inactive, student
    end
  end

  test "inactive matches a student with weekly_frequency=5 and last session 4 days ago (cutoff 3d)" do
    travel_to INACTIVE_NOW do
      student = build_student_with_completed_plan!(weekly_frequency: 5, plan_created_at: 30.days.ago)
      finish_session_for!(student, at: 4.days.ago)

      assert_includes Student.inactive, student
    end
  end

  test "inactive matches a student with weekly_frequency=null and last session 11 days ago (10-day fallback)" do
    travel_to INACTIVE_NOW do
      student = build_student_with_completed_plan!(weekly_frequency: nil, plan_created_at: 30.days.ago)
      finish_session_for!(student, at: 11.days.ago)

      assert_includes Student.inactive, student
    end
  end

  test "inactive does NOT match a student with weekly_frequency=null and last session 9 days ago (10-day fallback)" do
    travel_to INACTIVE_NOW do
      student = build_student_with_completed_plan!(weekly_frequency: nil, plan_created_at: 30.days.ago)
      finish_session_for!(student, at: 9.days.ago)

      assert_not_includes Student.inactive, student
    end
  end

  test "inactive matches a student who has never trained when their current version was promoted longer ago than the cutoff" do
    travel_to INACTIVE_NOW do
      student = build_student_with_completed_plan!(weekly_frequency: nil, plan_created_at: 11.days.ago)

      assert_includes Student.inactive, student
    end
  end

  test "inactive does NOT match a freshly-promoted student with no sessions" do
    travel_to INACTIVE_NOW do
      student = build_student_with_completed_plan!(weekly_frequency: nil, plan_created_at: Time.current)

      assert_not_includes Student.inactive, student
    end
  end

  test "inactive does NOT match a student whose current version is still generating" do
    @organization.students.destroy_all
    trainer = users(:one)
    travel_to INACTIVE_NOW do
      student = @organization.students.create!(name: "Gerando", anamnesis_md: "x")
      student.start_periodization!(trainer: trainer) # stays :generating, never promoted

      assert_not_includes Student.inactive, student
    end
  end

  test "inactive does NOT match a student without an active periodization" do
    @organization.students.destroy_all
    travel_to INACTIVE_NOW do
      student = @organization.students.create!(name: "Sem plano", anamnesis_md: "x")

      assert_not_includes Student.inactive, student
    end
  end

  test "inactive excludes archived students even when the cutoff would otherwise match" do
    travel_to INACTIVE_NOW do
      student = build_student_with_completed_plan!(weekly_frequency: nil, plan_created_at: 30.days.ago)
      student.archive!

      assert_not_includes Student.inactive, student
    end
  end

  test "without_active_plan matches unarchived students with no active periodization regardless of any historical version state" do
    @organization.students.destroy_all
    trainer = users(:one)
    no_plan = @organization.students.create!(name: "Sem plano")
    generating = @organization.students.create!(name: "Gerando")
    generating.start_periodization!(trainer: trainer)
    failed = @organization.students.create!(name: "Falhou")
    failed_version = failed.start_periodization!(trainer: trainer)
    failed_version.fail!("oops")
    completed = @organization.students.create!(name: "Pronto")
    completed_version = completed.start_periodization!(trainer: trainer)
    completed_version.complete!
    archived = @organization.students.create!(name: "Arquivado", archived_at: 1.day.ago)

    scope = Student.without_active_plan

    assert_includes scope, no_plan
    assert_not_includes scope, generating
    assert_not_includes scope, failed
    assert_not_includes scope, completed
    assert_not_includes scope, archived
  end

  private
    # Build an unarchived student in @organization with an active periodization
    # whose current_version is :completed and pinned. plan_created_at sets both
    # the periodization and the version created_at so the inactive cutoff's
    # "clock starts at promotion" branch is exercisable.
    def build_student_with_completed_plan!(weekly_frequency:, plan_created_at:)
      trainer = users(:one)
      student = @organization.students.create!(
        name: "Aluno #{SecureRandom.hex(3)}",
        anamnesis_md: "x",
        weekly_frequency: weekly_frequency
      )
      version = student.start_periodization!(trainer: trainer)
      version.complete!
      student.active_periodization.set_current_version!(version)
      version.update_columns(created_at: plan_created_at, updated_at: plan_created_at)
      student
    end

    def finish_session_for!(student, at:)
      trainer = users(:one)
      version = student.active_periodization.current_version
      session = TrainingSession.create!(
        student: student,
        trainer: trainer,
        periodization_version: version,
        workout_name_snapshot: "Treino A",
        workout_position_snapshot: 1,
        blocks_snapshot: [],
        progress: []
      )
      session.update_columns(created_at: at, finished_at: at)
      session
    end

  public

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
