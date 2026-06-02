require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path(email_address: @user.email_address)
    assert_nil cookies[:session_id]
    errors = session[:inertia_errors] || {}
    assert_includes errors.values.flatten, "E-mail ou senha incorretos."
  end

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "session whose authenticatable is not a User is rejected on a trainer-side controller" do
    non_user_session = Session.create!(authenticatable: organizations(:steimfit))

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = non_user_session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end

    # root_path is now public (renders the landing chooser), so probe an
    # auth-gated trainer page to assert the mismatched cookie is rejected.
    get students_path

    assert_redirected_to new_session_path
  end
end
