require "test_helper"

class AnalyticsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "requires authentication" do
    get analytics_path

    assert_redirected_to new_session_path
  end

  test "renders the analytics page for a signed-in trainer" do
    sign_in_as(@user)

    get analytics_path

    assert_response :success
    assert_equal "analytics/show", inertia.component
  end

  test "passes the training_sessions and periodizations day series" do
    student = students(:alice)
    TrainingSession.create!(
      student: student, trainer: @user,
      workout_name_snapshot: "A", workout_position_snapshot: 1
    )
    student.periodizations.create!

    sign_in_as(@user)
    get analytics_path

    sessions = inertia.props[:training_sessions]
    periodizations = inertia.props[:periodizations]

    assert_equal 14, sessions.length
    assert_equal 14, periodizations.length
    assert_operator sessions.sum { |d| d[:trainer] + d[:student] }, :>=, 1
    assert_operator periodizations.sum { |d| d[:count] }, :>=, 1
  end
end
