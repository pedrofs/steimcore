require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "redirects unauthenticated visitors to sign in" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "renders the home page for a signed-in trainer" do
    sign_in_as(@user)

    get root_path

    assert_response :success
  end

  test "shares current_organization derived from the signed-in user" do
    sign_in_as(@user)

    get root_path

    org = inertia.props[:current_organization]

    assert_equal @user.organization.id, org[:id]
    assert_equal @user.organization.name, org[:name]
  end

  test "shares a nil current_organization when nobody is signed in" do
    get new_session_path

    assert_nil inertia.props[:current_organization]
  end

  test "shares active_session_count as 0 when the trainer has no active sessions" do
    sign_in_as(@user)

    get root_path

    assert_equal 0, inertia.props[:active_session_count]
  end

  test "shares active_session_count counting only the current trainer's unfinished sessions" do
    organization = @user.organization
    student_a = students(:alice)
    student_b = students(:bob)
    other_user = users(:two)

    TrainingSession.create!(
      student: student_a, trainer: @user,
      workout_name_snapshot: "A", workout_position_snapshot: 1
    )
    finished = TrainingSession.create!(
      student: student_b, trainer: @user,
      workout_name_snapshot: "B", workout_position_snapshot: 1
    )
    finished.update!(finished_at: Time.current)
    TrainingSession.create!(
      student: student_b, trainer: other_user,
      workout_name_snapshot: "B", workout_position_snapshot: 1
    )

    sign_in_as(@user)

    get root_path

    assert_equal 1, inertia.props[:active_session_count]
    assert_equal organization, @user.organization
  end

  test "shares active_session_count as 0 when nobody is signed in" do
    get new_session_path

    assert_equal 0, inertia.props[:active_session_count]
  end

  test "passes the dashboard queue payload as a prop" do
    sign_in_as(@user)

    get root_path

    queue = inertia.props[:queue]
    assert_kind_of Hash, queue
    assert_kind_of Hash, queue[:counts]
    assert_kind_of Array, queue[:rows]
    assert_kind_of Integer, queue[:counts][:anamnesis_pending]
    assert_kind_of Integer, queue[:counts][:no_plan]
  end

  test "queue rows include only the current organization's students" do
    @user.organization.students.destroy_all
    @user.organization.students.create!(name: "Mine")

    other_org = Organization.create!(name: "Outro")
    other_org.students.create!(name: "Theirs")

    sign_in_as(@user)
    get root_path

    names = inertia.props[:queue][:rows].map { |r| r[:student][:name] }
    assert_includes names, "Mine"
    assert_not_includes names, "Theirs"
  end

  test "passes total_students count for the empty-state branch" do
    @user.organization.students.destroy_all
    @user.organization.students.create!(name: "Active")
    @user.organization.students.create!(name: "Archived", archived_at: 1.day.ago)

    sign_in_as(@user)
    get root_path

    assert_equal 1, inertia.props[:total_students]
  end
end
