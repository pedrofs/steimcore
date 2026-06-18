require "test_helper"

class JobsDashboardTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @user = users(:one)
  end

  test "unauthenticated users are redirected to the login page" do
    get "/jobs"
    assert_response :redirect
    assert_equal "/session/new", URI.parse(response.location).path
  end

  test "authenticated users can load the jobs dashboard" do
    sign_in_as(@user)
    get "/jobs"
    assert_response :success
  end
end
