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

  test "archive! persists the reason when given" do
    student = Student.create!(name: "Dave", organization: @organization)

    student.archive!(reason: "Só faz crossfit (sem musculação)")

    assert student.archived?
    assert_equal "Só faz crossfit (sem musculação)", student.archive_reason
  end

  test "archive! leaves archive_reason nil when no reason is given" do
    student = Student.create!(name: "Dave", organization: @organization)

    student.archive!

    assert student.archived?
    assert_nil student.archive_reason
  end

  test "archive! treats blank reason as no reason" do
    student = Student.create!(name: "Dave", organization: @organization)

    student.archive!(reason: "   ")

    assert_nil student.archive_reason
  end

  test "restore! clears archived_at and archive_reason" do
    student = Student.create!(name: "Dave", organization: @organization)
    student.archive!(reason: "Mudou de academia")

    student.restore!

    assert_not student.archived?
    assert_nil student.archived_at
    assert_nil student.archive_reason
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
    version.periodization_length_weeks = 8
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
    version.periodization_length_weeks = 8
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
    version.periodization_length_weeks = 8
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
    completed_version.periodization_length_weeks = 8
    completed_version.complete!
    archived = @organization.students.create!(name: "Arquivado", archived_at: 1.day.ago)

    scope = Student.without_active_plan

    assert_includes scope, no_plan
    assert_not_includes scope, generating
    assert_not_includes scope, failed
    assert_not_includes scope, completed
    assert_not_includes scope, archived
  end

  test "periodization_overdue matches when finished sessions exceed the target" do
    @organization.students.destroy_all
    student = overdue_student!(remaining: -1)

    assert_includes Student.periodization_overdue, student
  end

  test "periodization_overdue does NOT match at the target boundary (sessions_remaining 0)" do
    @organization.students.destroy_all
    student = overdue_student!(remaining: 0)

    assert_not_includes Student.periodization_overdue, student
  end

  test "periodization_overdue counts finished sessions across superseded versions of the active periodization" do
    @organization.students.destroy_all
    trainer = users(:one)
    student = @organization.students.create!(name: "Vencida histórica", anamnesis_md: "x", weekly_frequency: 1)
    v1 = student.start_periodization!(trainer: trainer)
    v1.periodization_length_weeks = 1 # target 1
    v1.complete!
    student.active_periodization.set_current_version!(v1)
    finish_session_for!(student.reload, at: Time.current) # 1 session on v1
    # Fork + promote v2; v1 becomes superseded but its session still counts.
    v2 = student.active_periodization.start_edit!(scope: :periodization, trainer: trainer)
    v2.periodization_length_weeks = 1
    v2.complete!
    student.active_periodization.set_current_version!(v2)
    finish_session_for!(student.reload, at: Time.current) # 1 session on v2 → 2 > target 1

    assert_includes Student.periodization_overdue, student
  end

  test "periodization_overdue excludes students with no active periodization" do
    @organization.students.destroy_all
    @organization.students.create!(name: "Sem plano", anamnesis_md: "x", weekly_frequency: 3)

    assert_empty Student.periodization_overdue
  end

  test "periodization_overdue excludes students with null weekly_frequency" do
    @organization.students.destroy_all
    student = overdue_student!(remaining: -2)
    student.update_columns(weekly_frequency: nil)

    assert_not_includes Student.periodization_overdue, student
  end

  test "periodization_overdue excludes students with zero weekly_frequency" do
    @organization.students.destroy_all
    student = overdue_student!(remaining: -2)
    student.update_columns(weekly_frequency: 0)

    assert_not_includes Student.periodization_overdue, student
  end

  test "periodization_overdue excludes students whose current version has null periodization_length_weeks" do
    @organization.students.destroy_all
    student = overdue_student!(remaining: -2)
    student.active_periodization.current_version.update_columns(periodization_length_weeks: nil)

    assert_not_includes Student.periodization_overdue, student.reload
  end

  test "periodization_overdue excludes archived students" do
    @organization.students.destroy_all
    student = overdue_student!(remaining: -2)
    student.archive!

    assert_not_includes Student.periodization_overdue, student
  end

  test "periodization_overdue_sort_value returns sessions_remaining" do
    @organization.students.destroy_all
    student = overdue_student!(remaining: -3)

    assert_equal(-3, student.periodization_overdue_sort_value)
  end

  test "periodization_due matches when sessions_remaining is within [0, 5)" do
    @organization.students.destroy_all
    student = due_student!(remaining: 2)

    assert_includes Student.periodization_due, student
  end

  test "periodization_due matches at the lower boundary (sessions_remaining 0)" do
    @organization.students.destroy_all
    student = due_student!(remaining: 0)

    assert_includes Student.periodization_due, student
  end

  test "periodization_due matches at sessions_remaining 4" do
    @organization.students.destroy_all
    student = due_student!(remaining: 4)

    assert_includes Student.periodization_due, student
  end

  test "periodization_due does NOT match at the upper boundary (sessions_remaining 5)" do
    @organization.students.destroy_all
    student = due_student!(remaining: 5)

    assert_not_includes Student.periodization_due, student
  end

  test "periodization_due does NOT match an overdue student (sessions_remaining -1)" do
    @organization.students.destroy_all
    student = due_student!(remaining: -1)

    assert_not_includes Student.periodization_due, student
  end

  test "periodization_due counts finished sessions across superseded versions of the active periodization" do
    @organization.students.destroy_all
    trainer = users(:one)
    student = @organization.students.create!(name: "Due histórica", anamnesis_md: "x", weekly_frequency: 1)
    v1 = student.start_periodization!(trainer: trainer)
    v1.periodization_length_weeks = 8 # target 8
    v1.complete!
    student.active_periodization.set_current_version!(v1)
    finish_session_for!(student.reload, at: Time.current) # 1 session on v1
    # Fork + promote v2; v1 becomes superseded but its session still counts.
    v2 = student.active_periodization.start_edit!(scope: :periodization, trainer: trainer)
    v2.periodization_length_weeks = 8
    v2.complete!
    student.active_periodization.set_current_version!(v2)
    6.times { finish_session_for!(student.reload, at: Time.current) } # 7 done → remaining 1 → due

    assert_includes Student.periodization_due, student
  end

  test "periodization_due excludes students with no active periodization" do
    @organization.students.destroy_all
    @organization.students.create!(name: "Sem plano", anamnesis_md: "x", weekly_frequency: 3)

    assert_empty Student.periodization_due
  end

  test "periodization_due excludes students with null weekly_frequency" do
    @organization.students.destroy_all
    student = due_student!(remaining: 2)
    student.update_columns(weekly_frequency: nil)

    assert_not_includes Student.periodization_due, student
  end

  test "periodization_due excludes students with zero weekly_frequency" do
    @organization.students.destroy_all
    student = due_student!(remaining: 2)
    student.update_columns(weekly_frequency: 0)

    assert_not_includes Student.periodization_due, student
  end

  test "periodization_due excludes students whose current version has null periodization_length_weeks" do
    @organization.students.destroy_all
    student = due_student!(remaining: 2)
    student.active_periodization.current_version.update_columns(periodization_length_weeks: nil)

    assert_not_includes Student.periodization_due, student.reload
  end

  test "periodization_due excludes archived students" do
    @organization.students.destroy_all
    student = due_student!(remaining: 2)
    student.archive!

    assert_not_includes Student.periodization_due, student
  end

  test "periodization_due_sort_value returns sessions_remaining" do
    @organization.students.destroy_all
    student = due_student!(remaining: 3)

    assert_equal 3, student.periodization_due_sort_value
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
      version.periodization_length_weeks = 8
      version.complete!
      student.active_periodization.set_current_version!(version)
      version.update_columns(created_at: plan_created_at, updated_at: plan_created_at)
      student
    end

    # Builds an unarchived student whose active periodization is completed and
    # promoted, with enough finished sessions to land on the requested
    # sessions_remaining (target = length_weeks × weekly_frequency).
    def overdue_student!(remaining:, weekly_frequency: 1, length_weeks: 2)
      trainer = users(:one)
      student = @organization.students.create!(
        name: "Vencida #{SecureRandom.hex(3)}",
        anamnesis_md: "x",
        weekly_frequency: weekly_frequency
      )
      version = student.start_periodization!(trainer: trainer)
      version.periodization_length_weeks = length_weeks
      version.complete!
      student.active_periodization.set_current_version!(version)
      target = length_weeks * weekly_frequency
      (target - remaining).times { finish_session_for!(student.reload, at: Time.current) }
      student.reload
    end

    # Same shape as overdue_student! but with a length large enough that the
    # due thresholds (remaining 0..5) all yield a non-negative session count.
    def due_student!(remaining:, weekly_frequency: 1, length_weeks: 8)
      overdue_student!(remaining: remaining, weekly_frequency: weekly_frequency, length_weeks: length_weeks)
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
