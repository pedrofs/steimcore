require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
  end

  test "new redirects to login when unauthenticated" do
    get new_invitation_path
    assert_redirected_to new_session_path
  end

  test "create redirects to login when unauthenticated" do
    post invitations_path, params: { email_address: "stranger@example.com" }
    assert_redirected_to new_session_path
  end

  test "new renders" do
    sign_in_as(@user)
    get new_invitation_path
    assert_response :success
  end

  test "create persists the invitation, enqueues a mailer, and redirects with pt-BR notice" do
    sign_in_as(@user)

    assert_difference -> { Invitation.count } => 1 do
      assert_enqueued_emails 1 do
        post invitations_path, params: { email_address: "fresh@example.com" }
      end
    end

    invitation = Invitation.order(:created_at).last
    assert_equal "fresh@example.com", invitation.email_address
    assert_equal @organization, invitation.organization
    assert_equal @user, invitation.invited_by
    assert_redirected_to organization_path
    assert_match(/Convite enviado para fresh@example.com\./, flash[:notice])
  end

  test "create rejects when email is already a member of the organization" do
    sign_in_as(@user)

    assert_no_difference -> { Invitation.count } do
      assert_enqueued_emails 0 do
        post invitations_path, params: { email_address: users(:two).email_address }
      end
    end

    assert_redirected_to new_invitation_path(email_address: users(:two).email_address)
    errors = session[:inertia_errors] || {}
    assert errors.values.flatten.any? { |m| m.include?("Esse e-mail já é um membro da organização.") },
           "expected member-of-org error, got: #{errors.inspect}"
  end

  test "create rejects when email already exists in users in another organization" do
    other_org = Organization.create!(name: "Other org")
    User.create!(organization: other_org, email_address: "elsewhere@example.com", password: "password")

    sign_in_as(@user)
    assert_no_difference -> { Invitation.count } do
      assert_enqueued_emails 0 do
        post invitations_path, params: { email_address: "elsewhere@example.com" }
      end
    end

    errors = session[:inertia_errors] || {}
    assert errors.values.flatten.any? { |m| m.include?("E-mail já está em uso.") },
           "expected global-collision error, got: #{errors.inspect}"
  end

  test "create rejects when a pending invitation already exists for the same email in the same org" do
    sign_in_as(@user)
    existing = invitations(:pending)

    assert_no_difference -> { Invitation.count } do
      assert_enqueued_emails 0 do
        post invitations_path, params: { email_address: existing.email_address }
      end
    end

    errors = session[:inertia_errors] || {}
    assert errors.values.flatten.any? { |m| m.include?("Já existe um convite pendente para esse e-mail.") },
           "expected pending-collision error, got: #{errors.inspect}"
  end

  test "create scopes the new invitation to the trainer's organization" do
    other_org = Organization.create!(name: "Other org")
    other_trainer = User.create!(organization: other_org, email_address: "other-trainer@example.com", password: "password")

    sign_in_as(other_trainer)
    post invitations_path, params: { email_address: "newbie@example.com" }

    invitation = Invitation.find_by(email_address: "newbie@example.com")
    assert_equal other_org, invitation.organization
    assert_equal other_trainer, invitation.invited_by
  end
end
