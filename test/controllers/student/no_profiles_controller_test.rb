require "test_helper"

class Student::NoProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = student_identities(:confirmed)
  end

  test "show renders the no-profile page for a signed-in identity with no profiles" do
    sign_in_as(@identity)

    get student_no_profile_path

    assert_response :success
    assert_equal "student/home/no_profile", inertia.component
  end

  test "redirects to the student sign-in when not authenticated" do
    get student_no_profile_path

    assert_redirected_to new_student_session_path
  end
end
