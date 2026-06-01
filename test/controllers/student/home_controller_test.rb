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

  test "show renders the selected student's name and organization for a signed-in identity" do
    sign_in_with_selected_profile(@identity, @student)

    get student_home_path

    assert_response :success
    assert_equal "student/home/show", inertia.component
    assert_equal @student.name.split.first, inertia.props[:dashboard][:first_name]
    assert_equal organizations(:steimfit).name, inertia.props[:organization_name]
  end

  test "redirects to the student sign-in when not authenticated" do
    get student_home_path

    assert_redirected_to new_student_session_path
  end

  test "bounces to the no-profile page when the only selected student is destroyed mid-session" do
    sign_in_with_selected_profile(@identity, @student)
    @student.destroy!

    get student_home_path

    assert_redirected_to student_no_profile_path
  end

  test "bounces to the chooser when the selected one of two students is destroyed mid-session" do
    other_org = Organization.create!(name: "Other Gym", equipment_list_md: "")
    other_org.students.create!(name: "Other Profile", email: @identity.email_address)
    sign_in_with_selected_profile(@identity, @student)
    @student.destroy!

    get student_home_path

    assert_redirected_to new_student_profile_selection_path
  end

  private
    def sign_in_with_selected_profile(identity, student)
      sign_in_as(identity)
      identity.sessions.sole.update!(selected_student: student)
    end
end
