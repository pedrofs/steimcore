require "test_helper"

class InvitationAcceptancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @invitation = invitations(:pending)
    @token = @invitation.generate_token_for(:acceptance)
  end

  test "edit is reachable without authentication" do
    get edit_invitation_acceptance_path(@token)
    assert_response :success
  end

  test "edit redirects to login when the token signature is invalid" do
    get edit_invitation_acceptance_path("totally-bogus-token")
    assert_redirected_to new_session_path
    assert_equal "Este convite não é mais válido.", flash[:alert]
  end

  test "edit redirects to login when the token has expired" do
    travel 8.days do
      get edit_invitation_acceptance_path(@token)
    end
    assert_redirected_to new_session_path
    assert_equal "Este convite não é mais válido.", flash[:alert]
  end

  test "update with a valid token and matching password creates the user, signs them in, redirects to root" do
    assert_difference -> { User.count } => 1 do
      put invitation_acceptance_path(@token), params: {
        password: "newpassword",
        password_confirmation: "newpassword"
      }
    end

    user = User.order(:created_at).last
    assert_equal @invitation.email_address, user.email_address
    assert_equal @invitation.organization, user.organization
    assert_not_nil @invitation.reload.accepted_at
    assert cookies[:session_id]
    assert_redirected_to root_path
    assert_match(/Bem-vindo\(a\)/, flash[:notice])
  end

  test "update with a token whose invitation was already accepted redirects to login" do
    @invitation.accept!(password: "newpassword", password_confirmation: "newpassword")

    put invitation_acceptance_path(@token), params: {
      password: "another",
      password_confirmation: "another"
    }

    assert_redirected_to new_session_path
    assert_equal "Este convite não é mais válido.", flash[:alert]
  end

  test "update with mismatched password re-renders edit with inertia errors" do
    assert_no_difference -> { User.count } do
      put invitation_acceptance_path(@token), params: {
        password: "secret-one",
        password_confirmation: "secret-two"
      }
    end

    assert_redirected_to edit_invitation_acceptance_path(@token)
    errors = session[:inertia_errors] || {}
    assert errors.values.flatten.any? { |m| m.match?(/doesn't match/i) },
           "expected confirmation-mismatch error, got: #{errors.inspect}"
    assert_nil @invitation.reload.accepted_at
  end

  test "update surfaces a user-facing error when the email is taken at accept time" do
    User.create!(
      organization: Organization.create!(name: "Race org"),
      email_address: @invitation.email_address,
      password: "password"
    )

    assert_no_difference -> { User.where.not(email_address: @invitation.email_address).count } do
      put invitation_acceptance_path(@token), params: {
        password: "newpassword",
        password_confirmation: "newpassword"
      }
    end

    assert_redirected_to edit_invitation_acceptance_path(@token)
    errors = session[:inertia_errors] || {}
    assert errors.values.flatten.any? { |m| m.include?("E-mail já está em uso.") },
           "expected email-conflict error, got: #{errors.inspect}"
    assert_nil @invitation.reload.accepted_at
  end
end
