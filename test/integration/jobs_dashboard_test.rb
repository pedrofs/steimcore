require "test_helper"

class JobsDashboardTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  BASIC_AUTH_USER = "trainer".freeze
  BASIC_AUTH_PASSWORD = "secret".freeze

  setup do
    @user = users(:one)

    # Test env has no mission_control credentials, so configure them here.
    @previous_user = MissionControl::Jobs.http_basic_auth_user
    @previous_password = MissionControl::Jobs.http_basic_auth_password
    MissionControl::Jobs.http_basic_auth_user = BASIC_AUTH_USER
    MissionControl::Jobs.http_basic_auth_password = BASIC_AUTH_PASSWORD
  end

  teardown do
    MissionControl::Jobs.http_basic_auth_user = @previous_user
    MissionControl::Jobs.http_basic_auth_password = @previous_password
  end

  test "unauthenticated users are redirected to the login page" do
    get "/jobs"
    assert_response :redirect
    assert_equal "/session/new", URI.parse(response.location).path
  end

  test "signed-in trainers without basic auth credentials are rejected" do
    sign_in_as(@user)
    get "/jobs"
    assert_response :unauthorized
  end

  test "signed-in trainers with basic auth credentials can load the dashboard" do
    sign_in_as(@user)
    get "/jobs", headers: basic_auth_headers
    assert_response :success
  end

  private
    def basic_auth_headers
      encoded = ActionController::HttpAuthentication::Basic.encode_credentials(
        BASIC_AUTH_USER, BASIC_AUTH_PASSWORD
      )
      { "Authorization" => encoded }
    end
end
