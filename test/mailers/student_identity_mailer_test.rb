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

  test "password_reset is addressed to the identity with a pt-BR subject" do
    identity = student_identities(:confirmed)
    mail = StudentIdentityMailer.password_reset(identity)

    assert_equal [ identity.email_address ], mail.to
    assert_equal [ "SteimFit <no-reply@steimfit.com>" ], [ mail[:from].decoded ]
    assert_equal "Redefina sua senha", mail.subject
  end

  test "password_reset html body is pt-BR with a verifiable reset URL pointing at the student edit page" do
    identity = student_identities(:confirmed)
    body = StudentIdentityMailer.password_reset(identity).html_part.body.to_s

    assert_match "redefinir sua senha", body
    assert_match "Este link expira em 15 minutos.", body
    assert_match %r{/student/passwords/[^/]+/edit}, body

    token = body.match(%r{/student/passwords/([^/\s"<]+)/edit})[1]
    assert_equal identity, StudentIdentity.find_by_password_reset_token!(token)
  end

  test "password_reset text body is pt-BR with a verifiable reset URL pointing at the student edit page" do
    identity = student_identities(:confirmed)
    text = StudentIdentityMailer.password_reset(identity).text_part.body.to_s

    assert_match "redefinir sua senha", text
    assert_match "Este link expira em 15 minutos.", text
    assert_match %r{/student/passwords/[^/]+/edit}, text

    token = text.match(%r{/student/passwords/([^/\s"<]+)/edit})[1]
    assert_equal identity, StudentIdentity.find_by_password_reset_token!(token)
  end
end
