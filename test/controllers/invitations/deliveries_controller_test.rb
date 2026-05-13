require "test_helper"

class Invitations::DeliveriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @invitation = invitations(:pending)
  end

  test "create redirects to login when unauthenticated" do
    post invitation_delivery_path(@invitation)
    assert_redirected_to new_session_path
  end

  test "create bumps updated_at, enqueues a mailer, and redirects with the resend flash" do
    sign_in_as(@user)

    previous_updated_at = @invitation.updated_at

    travel 1.second do
      assert_enqueued_emails 1 do
        post invitation_delivery_path(@invitation)
      end
    end

    assert @invitation.reload.updated_at > previous_updated_at
    assert_redirected_to organization_path
    assert_equal "Convite reenviado para #{@invitation.email_address}.", flash[:notice]
  end

  test "create invalidates the previously issued token" do
    sign_in_as(@user)
    stale_token = @invitation.generate_token_for(:acceptance)

    travel 1.second do
      post invitation_delivery_path(@invitation)
    end

    assert_nil Invitation.find_by_token_for(:acceptance, stale_token),
               "stale token should not verify after resend"
  end

  test "create on another org's invitation 404s" do
    other_org = Organization.create!(name: "Other org")
    other_trainer = User.create!(organization: other_org, email_address: "other-trainer@example.com", password: "password")
    foreign_invitation = Invitation.create!(
      organization: other_org,
      invited_by: other_trainer,
      email_address: "foreign@example.com"
    )

    sign_in_as(@user)
    assert_enqueued_emails 0 do
      post invitation_delivery_path(foreign_invitation)
    end
    assert_response :not_found
  end
end
