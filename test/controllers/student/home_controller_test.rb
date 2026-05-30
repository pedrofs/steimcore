require "test_helper"

class Student::HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = student_identities(:confirmed)
    @student = @identity.students.create!(
      name: "Connie Confirmed",
      organization: organizations(:steimfit),
      email: @identity.email_address
    )
  end

  test "show renders the student's name and organization for a signed-in identity" do
    sign_in_as(@identity)

    get student_home_path

    assert_response :success
    assert_equal "student/home/show", inertia.component
    assert_equal @student.name, inertia.props[:student_name]
    assert_equal organizations(:steimfit).name, inertia.props[:organization_name]
  end

  test "redirects to the student sign-in when not authenticated" do
    get student_home_path

    assert_redirected_to new_student_session_path
  end
end
