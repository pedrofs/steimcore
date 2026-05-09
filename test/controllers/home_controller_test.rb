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
end
