require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @inviter = users(:one)
    @invitation = invitations(:pending)
  end

  test "normalizes email_address by stripping and downcasing" do
    invitation = Invitation.new(
      organization: @organization,
      invited_by: @inviter,
      email_address: "  HELLO@EXAMPLE.COM  "
    )
    assert_equal "hello@example.com", invitation.email_address
  end

  test "validates presence of email_address" do
    invitation = Invitation.new(organization: @organization, invited_by: @inviter, email_address: "")
    assert_not invitation.valid?
    assert_includes invitation.errors[:email_address], "can't be blank"
  end

  test "validates email_address format" do
    invitation = Invitation.new(organization: @organization, invited_by: @inviter, email_address: "not-an-email")
    assert_not invitation.valid?
    assert invitation.errors[:email_address].any? { |m| m.match?(/invalid/i) }
  end

  test "rejects when email is already a member of the same organization" do
    invitation = Invitation.new(
      organization: @organization,
      invited_by: @inviter,
      email_address: users(:two).email_address
    )
    assert_not invitation.valid?
    assert_includes invitation.errors[:email_address], "Esse e-mail já é um membro da organização."
  end

  test "rejects when email already exists in users in another organization" do
    other_org = Organization.create!(name: "Other org")
    other_user = User.create!(
      organization: other_org,
      email_address: "elsewhere@example.com",
      password: "password"
    )

    invitation = Invitation.new(
      organization: @organization,
      invited_by: @inviter,
      email_address: other_user.email_address
    )
    assert_not invitation.valid?
    assert_includes invitation.errors[:email_address], "E-mail já está em uso."
  end

  test "rejects when a pending invitation already exists for the same email in the same org" do
    duplicate = Invitation.new(
      organization: @organization,
      invited_by: @inviter,
      email_address: @invitation.email_address
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email_address], "Já existe um convite pendente para esse e-mail."
  end

  test "allows a fresh invitation when prior one was accepted" do
    accepted = invitations(:accepted)
    invitation = Invitation.new(
      organization: accepted.organization,
      invited_by: @inviter,
      email_address: accepted.email_address
    )
    assert invitation.valid?, "expected fresh invite to be valid, errors: #{invitation.errors.full_messages}"
  end

  test "generates a verifiable acceptance token" do
    token = @invitation.generate_token_for(:acceptance)
    assert_equal @invitation, Invitation.find_by_token_for!(:acceptance, token)
  end

  test "touch invalidates a previously issued token" do
    token = @invitation.generate_token_for(:acceptance)
    travel 1.second do
      @invitation.touch
    end
    assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
      Invitation.find_by_token_for!(:acceptance, token)
    end
  end

  test "accept! invalidates a previously issued token" do
    token = @invitation.generate_token_for(:acceptance)
    travel 1.second do
      @invitation.accept!(password: "newpassword", password_confirmation: "newpassword")
    end
    assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
      Invitation.find_by_token_for!(:acceptance, token)
    end
  end

  test "token stops verifying after 7 days" do
    token = @invitation.generate_token_for(:acceptance)
    travel 8.days do
      assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
        Invitation.find_by_token_for!(:acceptance, token)
      end
    end
  end

  test "accept! creates a User in the invitation's organization, stamps accepted_at, returns the User" do
    invitation = @invitation
    user = nil
    assert_difference -> { User.count } => 1 do
      user = invitation.accept!(password: "newpassword", password_confirmation: "newpassword")
    end
    assert_equal invitation.organization, user.organization
    assert_equal invitation.email_address, user.email_address
    assert_not_nil invitation.reload.accepted_at
  end

  test "accept! rolls back when password confirmation does not match" do
    invitation = @invitation
    assert_no_difference -> { User.count } do
      assert_raises ActiveRecord::RecordInvalid do
        invitation.accept!(password: "newpassword", password_confirmation: "mismatch")
      end
    end
    assert_nil invitation.reload.accepted_at
  end

  test "accept! rescues unique-violation race and raises EmailAlreadyTaken" do
    invitation = @invitation
    User.create!(
      organization: Organization.create!(name: "Race org"),
      email_address: invitation.email_address,
      password: "password"
    )

    assert_raises Invitation::EmailAlreadyTaken do
      invitation.accept!(password: "newpassword", password_confirmation: "newpassword")
    end
    assert_nil invitation.reload.accepted_at
  end

  test "expired? is true once created_at is older than 7 days" do
    invitation = invitations(:pending)
    assert_not invitation.expired?
    travel 8.days do
      assert invitation.expired?
    end
  end
end
