require "test_helper"

class StudentIdentityMailerTest < ActionMailer::TestCase
  setup do
    @identity = student_identities(:pending)
    @organization = organizations(:steimfit)
    @mail = StudentIdentityMailer.setup_invitation(@identity, organization: @organization)
  end

  test "to is the identity's email address" do
    assert_equal [ @identity.email_address ], @mail.to
  end

  test "from is the SteimFit no-reply with display name" do
    assert_equal [ "SteimFit <no-reply@steimfit.com>" ], [ @mail[:from].decoded ]
  end

  test "subject is pt-BR and includes the organization name" do
    assert_equal "Você foi convidado(a) para o #{@organization.name}", @mail.subject
  end

  test "html body identifies the org by name only and carries a verifiable setup URL" do
    body = @mail.html_part.body.to_s

    assert_match @organization.name, body
    assert_match "Este link expira em 30 dias.", body
    assert_match %r{/student/setup_acceptances/}, body

    token = body.match(%r{/student/setup_acceptances/([^/\s"<]+)})[1]
    assert_equal @identity, StudentIdentity.find_by_token_for!(:setup, token)
  end

  test "text body identifies the org by name only and carries a verifiable setup URL" do
    text = @mail.text_part.body.to_s

    assert_match @organization.name, text
    assert_match "Este link expira em 30 dias.", text
    assert_match %r{/student/setup_acceptances/}, text

    token = text.match(%r{/student/setup_acceptances/([^/\s"<]+)})[1]
    assert_equal @identity, StudentIdentity.find_by_token_for!(:setup, token)
  end
end
