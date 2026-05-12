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
      student: { name: "Frank", age: 99, anamnesis_md: "should not be set yet" }
    }

    student = @organization.students.find_by!(name: "Frank")
    assert_nil student.age
    assert_equal "", student.anamnesis_md
  end

  test "show renders the full student profile" do
    student = @organization.students.create!(
      name: "Grace",
      age: 28,
      sex: "Feminino",
      primary_goal: "Hipertrofia",
      restrictions_summary: "Joelho",
      weekly_frequency: 3,
      anamnesis_md: "## Anamnese",
      notes_md: "obs"
    )
    sign_in_as(@user)

    get student_path(student)

    assert_response :success
    assert_equal "students/show", inertia.component
    props = inertia.props[:student]
    assert_equal student.id, props[:id]
    assert_equal "Grace", props[:name]
    assert_equal 28, props[:age]
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
        age: 41,
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
    assert_equal 41, student.age
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
