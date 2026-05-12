require "test_helper"

class TrainingSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "index redirects unauthenticated visitors to sign in" do
    get training_sessions_path
    assert_redirected_to new_session_path
  end

  test "index renders the empty-state component with three props" do
    sign_in_as(@user)

    get training_sessions_path

    assert_response :success
    assert_equal "training_sessions/index", inertia.component
    assert_equal [], inertia.props[:training_sessions]
    assert_equal [], inertia.props[:picker_candidates]
    assert_equal "trainer", inertia.props[:scope]
  end
end
