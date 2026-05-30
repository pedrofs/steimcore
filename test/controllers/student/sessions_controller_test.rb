require "test_helper"

class Student::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = student_identities(:confirmed)
    @identity.students.create!(
      name: "Connie Confirmed",
      organization: organizations(:steimfit),
      email: @identity.email_address
    )
  end

  test "new renders the student sign-in page" do
    get new_student_session_path

    assert_response :success
    assert_equal "student/sessions/new", inertia.component
  end

  test "create with valid credentials and a single profile auto-selects it and lands on the student home" do
    post student_session_path, params: { email_address: @identity.email_address, password: "password" }

    assert_redirected_to student_home_path
    assert cookies[:session_id]
    assert_equal @identity.students.sole.id, @identity.sessions.sole.selected_student_id
  end

  test "create with two or more profiles lands on the chooser without auto-selecting" do
    other_org = Organization.create!(name: "Other Gym", equipment_list_md: "")
    other_org.students.create!(name: "Second Profile", email: @identity.email_address)

    post student_session_path, params: { email_address: @identity.email_address, password: "password" }

    assert_redirected_to new_student_profile_selection_path
    assert_nil @identity.sessions.sole.selected_student_id
  end

  test "every sign-in with multiple profiles forces a fresh choice with no remembered default" do
    other_org = Organization.create!(name: "Other Gym", equipment_list_md: "")
    other_org.students.create!(name: "Second Profile", email: @identity.email_address)

    # First sign-in: pick a profile, then sign out.
    post student_session_path, params: { email_address: @identity.email_address, password: "password" }
    chosen = @identity.students.first
    post student_profile_selection_path, params: { student_id: chosen.id }
    delete student_session_path

    # Second sign-in: must land on the chooser again, with no remembered default.
    post student_session_path, params: { email_address: @identity.email_address, password: "password" }

    assert_redirected_to new_student_profile_selection_path
    assert_nil @identity.sessions.sole.selected_student_id
  end

  test "create with zero linked profiles lands on the no-profile page" do
    @identity.students.destroy_all

    post student_session_path, params: { email_address: @identity.email_address, password: "password" }

    assert_redirected_to student_no_profile_path
  end

  test "create with invalid credentials redirects back with an error" do
    post student_session_path, params: { email_address: @identity.email_address, password: "wrong" }

    assert_redirected_to new_student_session_path(email_address: @identity.email_address)
    assert_nil cookies[:session_id]
    errors = session[:inertia_errors] || {}
    assert_includes errors.values.flatten, "E-mail ou senha incorretos."
  end

  test "destroy terminates the session and clears the cookie" do
    sign_in_as(@identity)

    delete student_session_path

    assert_redirected_to new_student_session_path
    assert_empty cookies[:session_id]
  end

  test "a User session cookie is rejected on a student-side controller" do
    sign_in_as(users(:one))

    get student_home_path

    assert_redirected_to new_student_session_path
  end

  test "a StudentIdentity session cookie is rejected on a trainer-side controller" do
    sign_in_as(@identity)

    get root_path

    assert_redirected_to new_session_path
  end
end
