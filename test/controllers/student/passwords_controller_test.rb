require "test_helper"

class Student::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = student_identities(:confirmed)
  end

  test "new renders the student forgot-password page" do
    get new_student_password_path

    assert_response :success
    assert_equal "student/passwords/new", inertia.component
  end

  test "create with a known email enqueues the reset mailer and redirects without enumeration" do
    post student_passwords_path, params: { email_address: @identity.email_address }

    assert_enqueued_email_with StudentIdentityMailer, :password_reset, args: [ @identity ]
    assert_redirected_to new_student_session_path
    assert_equal "Se houver uma conta com esse e-mail, enviamos instruções para redefinir a senha.", flash[:notice]
  end

  test "create with an unknown email redirects identically and sends no mail" do
    post student_passwords_path, params: { email_address: "nobody@example.com" }

    assert_enqueued_emails 0
    assert_redirected_to new_student_session_path
    assert_equal "Se houver uma conta com esse e-mail, enviamos instruções para redefinir a senha.", flash[:notice]
  end

  test "create is rate-limited after the configured threshold" do
    with_counting_rate_limit_store do
      11.times do
        post student_passwords_path, params: { email_address: @identity.email_address }
      end
    end

    assert_redirected_to new_student_password_path
    assert_equal "Tente novamente em alguns minutos.", flash[:alert]
  end

  test "edit with a valid token renders the reset page" do
    get edit_student_password_path(@identity.password_reset_token)

    assert_response :success
    assert_equal "student/passwords/edit", inertia.component
    assert_equal @identity, StudentIdentity.find_by_password_reset_token!(inertia.props[:token])
  end

  test "edit with an invalid token redirects with alert" do
    get edit_student_password_path("not-a-real-token")

    assert_redirected_to new_student_password_path
    assert_equal "O link de redefinição é inválido ou expirou.", flash[:alert]
  end

  test "edit with an expired token redirects with alert" do
    token = @identity.password_reset_token

    travel 16.minutes do
      get edit_student_password_path(token)
    end

    assert_redirected_to new_student_password_path
    assert_equal "O link de redefinição é inválido ou expirou.", flash[:alert]
  end

  test "update with a valid token and matching password sets the digest" do
    token = @identity.password_reset_token

    assert_changes -> { @identity.reload.password_digest } do
      put student_password_path(token), params: { password: "brand-new-pass", password_confirmation: "brand-new-pass" }
    end

    assert_redirected_to new_student_session_path
    assert_equal "Senha redefinida.", flash[:notice]
    assert @identity.reload.authenticate("brand-new-pass")
  end

  test "update destroys all of the identity's sessions" do
    @identity.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
    token = @identity.password_reset_token

    assert_changes -> { @identity.sessions.count }, to: 0 do
      put student_password_path(token), params: { password: "brand-new-pass", password_confirmation: "brand-new-pass" }
    end
  end

  test "update with mismatched passwords re-renders edit with errors" do
    token = @identity.password_reset_token

    assert_no_changes -> { @identity.reload.password_digest } do
      put student_password_path(token), params: { password: "one-password", password_confirmation: "another-password" }
    end

    assert_redirected_to edit_student_password_path(token)
    errors = session[:inertia_errors] || {}
    assert errors.values.flatten.any? { |m| m.match?(/doesn't match/i) },
           "expected a confirmation-mismatch error, got: #{errors.inspect}"
  end

  private
    # The test environment uses a :null_store cache, so rate limiting is a no-op
    # by default. The rate_limit macro captures the controller's cache store at
    # class-load time, so we override #increment on that captured store object to
    # delegate to a real counting store for the duration of the block.
    def with_counting_rate_limit_store
      counter = ActiveSupport::Cache::MemoryStore.new
      store = ApplicationController.cache_store
      store.define_singleton_method(:increment) { |name, amount = 1, **| counter.increment(name, amount) }
      yield
    ensure
      store.singleton_class.send(:remove_method, :increment)
    end
end
