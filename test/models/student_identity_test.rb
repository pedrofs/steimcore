require "test_helper"

class StudentIdentityTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @organization = organizations(:steimfit)
    @pending = student_identities(:pending)
    @confirmed = student_identities(:confirmed)
  end

  test "normalizes email_address by stripping and downcasing" do
    identity = StudentIdentity.new(email_address: "  HELLO@EXAMPLE.COM  ")
    assert_equal "hello@example.com", identity.email_address
  end

  test "confirmed? reflects presence of a password_digest" do
    assert @confirmed.confirmed?
    assert_not @pending.confirmed?
  end

  test "under_cooldown? is true only within 24h of the last invite" do
    assert_not @pending.under_cooldown?

    @pending.update!(last_invited_at: 23.hours.ago)
    assert @pending.under_cooldown?

    @pending.update!(last_invited_at: 25.hours.ago)
    assert_not @pending.under_cooldown?
  end

  test "invitable? requires pending and not under cooldown" do
    assert @pending.invitable?

    @pending.update!(last_invited_at: 1.hour.ago)
    assert_not @pending.invitable?

    assert_not @confirmed.invitable?
  end

  test "cooldown_available_at is 24h after the last invite, nil when never invited" do
    assert_nil @pending.cooldown_available_at

    @pending.update!(last_invited_at: Time.current)
    assert_in_delta @pending.last_invited_at + 24.hours, @pending.cooldown_available_at, 1.second
  end

  test "invite! stamps last_invited_at and enqueues the setup mailer" do
    assert_enqueued_email_with StudentIdentityMailer, :setup_invitation,
      args: [ @pending, { organization: @organization } ] do
      assert_changes -> { @pending.last_invited_at } do
        @pending.invite!(from_organization: @organization)
      end
    end
  end

  test "invite! raises UnderCooldown when a recent invite is still cooling down" do
    @pending.update!(last_invited_at: 1.hour.ago)

    assert_no_enqueued_emails do
      assert_raises StudentIdentity::UnderCooldown do
        @pending.invite!(from_organization: @organization)
      end
    end
  end

  test "invite! is a no-op for a confirmed identity" do
    assert_no_enqueued_emails do
      assert_no_changes -> { @confirmed.reload.last_invited_at } do
        @confirmed.invite!(from_organization: @organization)
      end
    end
  end

  test "mints a verifiable :setup token that expires after 30 days" do
    token = @pending.generate_token_for(:setup)
    assert_equal @pending, StudentIdentity.find_by_token_for!(:setup, token)

    travel 31.days do
      assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
        StudentIdentity.find_by_token_for!(:setup, token)
      end
    end
  end

  test "mints a verifiable :password_reset token that expires after 15 minutes" do
    token = @confirmed.generate_token_for(:password_reset)
    assert_equal @confirmed, StudentIdentity.find_by_token_for!(:password_reset, token)

    travel 16.minutes do
      assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
        StudentIdentity.find_by_token_for!(:password_reset, token)
      end
    end
  end
end
