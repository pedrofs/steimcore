require "test_helper"

class Student::ProfileSelectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = student_identities(:confirmed)
    @org_one = organizations(:steimfit)
    @org_two = Organization.create!(name: "Other Gym", equipment_list_md: "")
    @student_one = @org_one.students.create!(name: "Profile One", email: @identity.email_address)
    @student_two = @org_two.students.create!(name: "Profile Two", email: @identity.email_address)
  end

  test "new lists the identity's students with name and organization name" do
    sign_in_as(@identity)

    get new_student_profile_selection_path

    assert_response :success
    assert_equal "student/profile_selections/new", inertia.component
    names = inertia.props[:students].map { |s| s[:name] }
    org_names = inertia.props[:students].map { |s| s[:organization_name] }
    assert_includes names, "Profile One"
    assert_includes names, "Profile Two"
    assert_includes org_names, @org_one.name
    assert_includes org_names, @org_two.name
  end

  test "create writes selected_student_id and redirects to the home" do
    sign_in_as(@identity)
    session_record = @identity.sessions.sole

    post student_profile_selection_path, params: { student_id: @student_two.id }

    assert_redirected_to student_home_path
    assert_equal @student_two.id, session_record.reload.selected_student_id
  end

  test "create rejects a student_id not in the identity's students" do
    other_org = Organization.create!(name: "Unrelated Gym", equipment_list_md: "")
    foreign = other_org.students.create!(name: "Foreign", email: "someone-else@example.com")
    sign_in_as(@identity)
    session_record = @identity.sessions.sole

    post student_profile_selection_path, params: { student_id: foreign.id }

    assert_not_equal student_home_path, URI(response.location).path
    assert_nil session_record.reload.selected_student_id
  end
end
