require "test_helper"

class Analytics::UsagesControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "requires authentication" do
    get analytics_usage_path

    assert_redirected_to new_session_path
  end

  test "renders the usage tab for a signed-in trainer" do
    sign_in_as(@user)

    get analytics_usage_path

    assert_response :success
    assert_equal "analytics/usages/show", inertia.component
  end

  test "passes the usage analytics payload" do
    sign_in_as(@user)

    get analytics_usage_path

    assert_equal 14, inertia.props[:active_students].length
    assert inertia.props[:session_funnel].key?(:started)
    assert_equal 4, inertia.props[:app_open_states].length
    assert inertia.props[:totals].key?(:active_students)
  end
end
