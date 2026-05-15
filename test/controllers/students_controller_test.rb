require "test_helper"

class StudentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @organization = @user.organization
  end

  test "index redirects unauthenticated visitors to sign in" do
    get students_path
    assert_redirected_to new_session_path
  end

  test "index lists unarchived students from the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    other_org.students.create!(name: "Externo")
    @organization.students.create!(name: "Carol", archived_at: 1.day.ago)
    @organization.students.create!(name: "Dave")

    sign_in_as(@user)
    get students_path

    assert_response :success
    assert_equal "students/index", inertia.component
    names = inertia.props[:students].map { |s| s[:name] }
    assert_includes names, "Dave"
    assert_includes names, "Alice Trainer-Created"
    assert_not_includes names, "Carol"
    assert_not_includes names, "Externo"
  end

  test "index paginates at 25 per page and exposes pagination metadata" do
    @organization.students.destroy_all
    30.times { |i| @organization.students.create!(name: "Aluno #{format('%02d', i)}") }

    sign_in_as(@user)
    get students_path

    assert_response :success
    assert_equal 25, inertia.props[:students].length

    pagination = inertia.props[:pagination]
    assert_equal 1, pagination[:page]
    assert_equal 2, pagination[:pages]
    assert_equal 30, pagination[:count]
    assert_equal 1, pagination[:from]
    assert_equal 25, pagination[:to]
    assert_nil pagination[:prev]
    assert_equal 2, pagination[:next]
    assert_kind_of Array, pagination[:series]
  end

  test "index returns the second page when ?page=2" do
    @organization.students.destroy_all
    30.times { |i| @organization.students.create!(name: "Aluno #{format('%02d', i)}") }

    sign_in_as(@user)
    get students_path, params: { page: 2 }

    assert_response :success
    assert_equal 5, inertia.props[:students].length
    pagination = inertia.props[:pagination]
    assert_equal 2, pagination[:page]
    assert_equal 26, pagination[:from]
    assert_equal 30, pagination[:to]
    assert_equal 1, pagination[:prev]
    assert_nil pagination[:next]
  end

  test "index redirects page overflow to the last valid page" do
    @organization.students.destroy_all
    30.times { |i| @organization.students.create!(name: "Aluno #{format('%02d', i)}") }

    sign_in_as(@user)
    get students_path, params: { page: 99_999 }

    assert_redirected_to students_path(page: 2)
  end

  test "index does not redirect when a single-page result set is requested with page=1" do
    @organization.students.destroy_all
    @organization.students.create!(name: "Solo")

    sign_in_as(@user)
    get students_path

    assert_response :success
    pagination = inertia.props[:pagination]
    assert_equal 1, pagination[:page]
    assert_equal 1, pagination[:pages]
    assert_equal 1, pagination[:count]
  end

  test "index payload exposes active_periodization_id for each student" do
    @organization.students.destroy_all
    student_without = @organization.students.create!(name: "Sem")
    student_with = @organization.students.create!(name: "Com")
    periodization = student_with.periodizations.create!
    student_with.update!(active_periodization: periodization)

    sign_in_as(@user)
    get students_path

    payload = inertia.props[:students].index_by { |s| s[:id] }
    assert_nil payload[student_without.id][:active_periodization_id]
    assert_equal periodization.id, payload[student_with.id][:active_periodization_id]
  end

  test "index echoes back the current filters" do
    sign_in_as(@user)
    get students_path

    filters = inertia.props[:filters]
    assert_equal "", filters[:q]
    assert_equal false, filters[:without_active]
    assert_equal false, filters[:archived]

    get students_path, params: { q: "ana", without_active: "1", archived: "1" }
    filters = inertia.props[:filters]
    assert_equal "ana", filters[:q]
    assert_equal true, filters[:without_active]
    assert_equal true, filters[:archived]
  end

  test "index filters by case-insensitive substring on name when ?q= is present" do
    @organization.students.destroy_all
    @organization.students.create!(name: "Ana Silva")
    @organization.students.create!(name: "Mariana Costa")
    @organization.students.create!(name: "Bruno Souza")

    sign_in_as(@user)
    get students_path, params: { q: "ana" }

    names = inertia.props[:students].map { |s| s[:name] }
    assert_includes names, "Ana Silva"
    assert_includes names, "Mariana Costa"
    assert_not_includes names, "Bruno Souza"
  end

  test "index escapes LIKE wildcards in the q parameter" do
    @organization.students.destroy_all
    @organization.students.create!(name: "Maria 100%")
    @organization.students.create!(name: "Joana")

    sign_in_as(@user)
    get students_path, params: { q: "%" }

    names = inertia.props[:students].map { |s| s[:name] }
    assert_includes names, "Maria 100%"
    assert_not_includes names, "Joana"
  end

  test "index filters to students without an active periodization when ?without_active=1" do
    @organization.students.destroy_all
    without_active = @organization.students.create!(name: "Sem ativa")
    with_active = @organization.students.create!(name: "Com ativa")
    periodization = with_active.periodizations.create!
    with_active.update!(active_periodization: periodization)

    sign_in_as(@user)
    get students_path, params: { without_active: "1" }

    names = inertia.props[:students].map { |s| s[:name] }
    assert_includes names, without_active.name
    assert_not_includes names, with_active.name
  end

  test "index treats ?without_active=1 as a silent alias for ?status=no_plan" do
    @organization.students.destroy_all
    without_active = @organization.students.create!(name: "Sem ativa")
    with_active = @organization.students.create!(name: "Com ativa")
    periodization = with_active.periodizations.create!
    with_active.update!(active_periodization: periodization)

    sign_in_as(@user)

    get students_path, params: { without_active: "1" }
    legacy_names = inertia.props[:students].map { |s| s[:name] }.sort

    get students_path, params: { status: "no_plan" }
    new_names = inertia.props[:students].map { |s| s[:name] }.sort

    assert_equal legacy_names, new_names
    assert_equal [ without_active.name ], new_names
  end

  test "index filters to students without an active plan when ?status=no_plan" do
    @organization.students.destroy_all
    no_plan = @organization.students.create!(name: "Sem plano")
    with_plan = @organization.students.create!(name: "Com plano")
    periodization = with_plan.periodizations.create!
    with_plan.update!(active_periodization: periodization)

    sign_in_as(@user)
    get students_path, params: { status: "no_plan" }

    names = inertia.props[:students].map { |s| s[:name] }
    assert_includes names, no_plan.name
    assert_not_includes names, with_plan.name
    assert_equal "no_plan", inertia.props[:filters][:status]
  end

  test "index filters to anamnesis_pending students when ?status=anamnesis_pending" do
    @organization.students.destroy_all
    pending = @organization.students.create!(name: "Sem anamnese")
    filled = @organization.students.create!(name: "Com anamnese", anamnesis_md: "# História")

    sign_in_as(@user)
    get students_path, params: { status: "anamnesis_pending" }

    names = inertia.props[:students].map { |s| s[:name] }
    assert_includes names, pending.name
    assert_not_includes names, filled.name
  end

  test "index filters to plan_needs_action students when ?status=plan_needs_action" do
    @organization.students.destroy_all
    trainer = users(:one)

    needs_action = @organization.students.create!(name: "Com rascunho", anamnesis_md: "x")
    needs_action.start_periodization!(trainer: trainer).fail!("oops")

    promoted = @organization.students.create!(name: "Com plano promovido", anamnesis_md: "x")
    promoted_version = promoted.start_periodization!(trainer: trainer)
    promoted_version.complete!
    promoted.active_periodization.set_current_version!(promoted_version)

    sign_in_as(@user)
    get students_path, params: { status: "plan_needs_action" }

    names = inertia.props[:students].map { |s| s[:name] }
    assert_includes names, needs_action.name
    assert_not_includes names, promoted.name
    assert_equal "plan_needs_action", inertia.props[:filters][:status]
  end

  test "index echoes back the status filter" do
    sign_in_as(@user)
    get students_path, params: { status: "anamnesis_pending" }

    assert_equal "anamnesis_pending", inertia.props[:filters][:status]
  end

  test "index ignores unknown ?status= values" do
    @organization.students.destroy_all
    a = @organization.students.create!(name: "Alice", anamnesis_md: "# A")
    b = @organization.students.create!(name: "Bob")

    sign_in_as(@user)
    get students_path, params: { status: "bogus" }

    names = inertia.props[:students].map { |s| s[:name] }
    assert_includes names, a.name
    assert_includes names, b.name
    assert_nil inertia.props[:filters][:status]
  end

  test "index shows archived students when ?archived=1" do
    @organization.students.destroy_all
    @organization.students.create!(name: "Ativo")
    archived = @organization.students.create!(name: "Arquivado", archived_at: 1.day.ago)

    sign_in_as(@user)
    get students_path, params: { archived: "1" }

    names = inertia.props[:students].map { |s| s[:name] }
    assert_includes names, archived.name
    assert_not_includes names, "Ativo"
  end

  test "index composes filters with AND semantics" do
    @organization.students.destroy_all
    match = @organization.students.create!(name: "Ana sem ativa")
    @organization.students.create!(name: "Ana com ativa").tap do |s|
      p = s.periodizations.create!
      s.update!(active_periodization: p)
    end
    @organization.students.create!(name: "Bruno sem ativa")

    sign_in_as(@user)
    get students_path, params: { q: "ana", without_active: "1" }

    names = inertia.props[:students].map { |s| s[:name] }
    assert_equal [ match.name ], names
  end

  test "new renders the empty form" do
    sign_in_as(@user)

    get new_student_path

    assert_response :success
    assert_equal "students/new", inertia.component
  end

  test "create succeeds with only a name" do
    sign_in_as(@user)

    assert_difference -> { @organization.students.count }, 1 do
      post students_path, params: { student: { name: "Eve" } }
    end

    student = @organization.students.find_by!(name: "Eve")
    assert_redirected_to student_path(student)
    assert_equal "Aluno cadastrado.", flash[:notice]
  end

  test "create rejects a blank name and redirects back to the new form" do
    sign_in_as(@user)

    assert_no_difference -> { @organization.students.count } do
      post students_path, params: { student: { name: "" } }
    end

    assert_redirected_to new_student_path
  end

  test "create ignores fields outside the create whitelist" do
    sign_in_as(@user)

    post students_path, params: {
      student: { name: "Frank", birthday: "1990-01-01", anamnesis_md: "should not be set yet" }
    }

    student = @organization.students.find_by!(name: "Frank")
    assert_nil student.birthday
    assert_equal "", student.anamnesis_md
  end

  test "show renders the full student profile" do
    student = @organization.students.create!(
      name: "Grace",
      birthday: Date.new(1998, 6, 15),
      sex: "Feminino",
      primary_goal: "Hipertrofia",
      restrictions_summary: "Joelho",
      weekly_frequency: 3,
      anamnesis_md: "## Anamnese",
      notes_md: "obs"
    )
    sign_in_as(@user)

    travel_to Time.zone.local(2026, 6, 15, 10, 0, 0) do
      get student_path(student)
    end

    assert_response :success
    assert_equal "students/show", inertia.component
    props = inertia.props[:student]
    assert_equal student.id, props[:id]
    assert_equal "Grace", props[:name]
    assert_equal 28, props[:age]
    assert_equal "1998-06-15", props[:birthday]
    assert_equal "Feminino", props[:sex]
    assert_equal "Hipertrofia", props[:primary_goal]
    assert_equal "Joelho", props[:restrictions_summary]
    assert_equal 3, props[:weekly_frequency]
    assert_equal "## Anamnese", props[:anamnesis_md]
    assert_equal "obs", props[:notes_md]
    assert_equal false, props[:archived]
  end

  test "show allows opening archived students for inspection" do
    student = students(:archived_carol)
    sign_in_as(@user)

    get student_path(student)

    assert_response :success
    assert_equal student.id, inertia.props[:student][:id]
    assert_equal true, inertia.props[:student][:archived]
  end

  test "show exposes a frequency prop with the calendar-aligned 6-month window" do
    sign_in_as(@user)

    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      get student_path(students(:alice))

      assert_response :success
      frequency = inertia.props[:frequency]
      assert_not_nil frequency
      assert_equal Date.new(2025, 11, 17).to_s, frequency[:window_start].to_s
      assert_equal Date.new(2026, 5, 17).to_s, frequency[:window_end].to_s
      assert_equal 26 * 7, frequency[:days].length
    end
  end

  test "show exposes every session for a multi-session day in chronological order" do
    sign_in_as(@user)

    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      student = students(:alice)
      trainer = users(:one)
      periodization = student.periodizations.create!
      version = periodization.versions.create!(trainer: trainer, status: "completed")

      morning = TrainingSession.create!(
        student: student, trainer: trainer, periodization_version: version,
        workout_name_snapshot: "Treino A", workout_position_snapshot: 1,
        blocks_snapshot: [], progress: []
      )
      morning.update_columns(
        created_at: Time.zone.local(2026, 5, 13, 7, 0, 0),
        finished_at: Time.zone.local(2026, 5, 13, 8, 0, 0)
      )
      evening = TrainingSession.create!(
        student: student, trainer: trainer, periodization_version: version,
        workout_name_snapshot: "Treino B", workout_position_snapshot: 2,
        blocks_snapshot: [], progress: []
      )
      evening.update_columns(
        created_at: Time.zone.local(2026, 5, 13, 19, 0, 0),
        finished_at: Time.zone.local(2026, 5, 13, 20, 0, 0)
      )

      get student_path(student)

      frequency = inertia.props[:frequency]
      today_cell = frequency[:days].find { |d| d[:date].to_s == "2026-05-13" }
      assert_equal [ morning.id, evening.id ], today_cell[:sessions].map { |s| s[:id] }
      assert_equal [ "Treino A", "Treino B" ], today_cell[:sessions].map { |s| s[:workout_name_snapshot] }
    end
  end

  test "show returns frequency: nil for archived students" do
    sign_in_as(@user)

    get student_path(students(:archived_carol))

    assert_response :success
    assert_nil inertia.props[:frequency]
  end

  test "show is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    other_student = other_org.students.create!(name: "Externo")
    sign_in_as(@user)

    get student_path(other_student)

    assert_response :not_found
  end

  test "edit renders the editable form" do
    student = students(:alice)
    sign_in_as(@user)

    get edit_student_path(student)

    assert_response :success
    assert_equal "students/edit", inertia.component
    assert_equal student.id, inertia.props[:student][:id]
  end

  test "update persists structured and freeform fields" do
    student = students(:alice)
    sign_in_as(@user)

    patch student_path(student), params: {
      student: {
        birthday: "1985-04-02",
        sex: "Masculino",
        primary_goal: "Resistência",
        restrictions_summary: "Lombar",
        weekly_frequency: 5,
        anamnesis_md: "## Histórico\n\n- algo",
        notes_md: "lembretes"
      }
    }

    assert_redirected_to student_path(student)
    student.reload
    assert_equal Date.new(1985, 4, 2), student.birthday
    assert_equal "Masculino", student.sex
    assert_equal "Resistência", student.primary_goal
    assert_equal "Lombar", student.restrictions_summary
    assert_equal 5, student.weekly_frequency
    assert_equal "## Histórico\n\n- algo", student.anamnesis_md
    assert_equal "lembretes", student.notes_md
  end

  test "update rejects blank name and redirects back to edit" do
    student = students(:alice)
    original_name = student.name
    sign_in_as(@user)

    patch student_path(student), params: { student: { name: "" } }

    assert_redirected_to edit_student_path(student)
    assert_equal original_name, student.reload.name
  end

  test "update is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    other_student = other_org.students.create!(name: "Externo")
    sign_in_as(@user)

    patch student_path(other_student), params: { student: { name: "Hijack" } }

    assert_response :not_found
    assert_equal "Externo", other_student.reload.name
  end

  test "edits made by one trainer are visible to other trainers in the org" do
    student = @organization.students.create!(name: "Helena")
    sign_in_as(@user)
    patch student_path(student), params: { student: { primary_goal: "Hipertrofia" } }

    sign_out
    sign_in_as(@other_user)

    get student_path(student)

    assert_equal "Hipertrofia", inertia.props[:student][:primary_goal]
  end
end
