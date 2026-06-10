require "test_helper"

class Students::RestorationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:archived_carol)
  end

  test "create redirects unauthenticated visitors to sign in" do
    post student_restoration_path(@student)
    assert_redirected_to new_session_path
  end

  test "create restores the student and falls back to show without a referer" do
    sign_in_as(@user)

    post student_restoration_path(@student)

    assert_redirected_to student_path(@student)
    assert_equal "Aluno restaurado.", flash[:notice]
    assert_not @student.reload.archived?
  end

  test "create redirects back to the referring page when one is present" do
    sign_in_as(@user)

    post student_restoration_path(@student),
         headers: { "Referer" => students_url(archived: "1") }

    assert_redirected_to students_url(archived: "1")
    assert_not @student.reload.archived?
  end

  test "create on a student from another organization is scoped out (404)" do
    sign_in_as(@user)
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    foreign_student.archive!(reason: nil)

    post student_restoration_path(foreign_student)

    assert_response :not_found
    assert foreign_student.reload.archived?
  end
end
