require "test_helper"

class InvitationsMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @invitation = invitations(:pending)
    @mail = InvitationsMailer.invite(@invitation)
  end

  test "to is the invitee's email address" do
    assert_equal [ @invitation.email_address ], @mail.to
  end

  test "from is the SteimFit no-reply with display name" do
    assert_equal [ "SteimFit <no-reply@steimfit.com>" ], [ @mail[:from].decoded ]
  end

  test "subject is pt-BR and includes the organization name" do
    assert_equal "Você foi convidado(a) para o #{@invitation.organization.name}", @mail.subject
  end

  test "html body contains the inviter, organization, expiry note, and a verifiable acceptance URL" do
    body = @mail.html_part.body.to_s

    assert_match @invitation.invited_by.email_address, body
    assert_match @invitation.organization.name, body
    assert_match "Este link expira em 7 dias.", body
    assert_match %r{/invitation_acceptances/([^/]+)/edit}, body

    token = body.match(%r{/invitation_acceptances/([^/]+)/edit})[1]
    assert_equal @invitation, Invitation.find_by_token_for!(:acceptance, token)
  end

  test "text body contains the inviter, organization, expiry note, and a verifiable acceptance URL" do
    text = @mail.text_part.body.to_s

    assert_match @invitation.invited_by.email_address, text
    assert_match @invitation.organization.name, text
    assert_match "Este link expira em 7 dias.", text
    assert_match %r{/invitation_acceptances/([^/]+)/edit}, text

    token = text.match(%r{/invitation_acceptances/([^/]+)/edit})[1]
    assert_equal @invitation, Invitation.find_by_token_for!(:acceptance, token)
  end
end
