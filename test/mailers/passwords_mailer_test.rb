require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @user = users(:one)
    @mail = PasswordsMailer.reset(@user)
  end

  test "to is the user's email address" do
    assert_equal [ @user.email_address ], @mail.to
  end

  test "from is the SteimFit no-reply with display name" do
    assert_equal [ "SteimFit <no-reply@steimfit.com>" ], [ @mail[:from].decoded ]
  end

  test "subject is pt-BR" do
    assert_equal "Redefina sua senha", @mail.subject
  end

  test "html body is pt-BR with hardcoded expiry and a verifiable reset URL" do
    body = @mail.html_part.body.to_s

    assert_match "Você pode redefinir sua senha", body
    assert_match "página de redefinição de senha", body
    assert_match "Este link expira em 15 minutos.", body
    assert_match %r{/passwords/([^/]+)/edit}, body

    token = body.match(%r{/passwords/([^/]+)/edit})[1]
    assert_equal @user, User.find_by_password_reset_token!(token)
  end

  test "text body is pt-BR with hardcoded expiry and a verifiable reset URL" do
    text = @mail.text_part.body.to_s

    assert_match "Você pode redefinir sua senha", text
    assert_match "Este link expira em 15 minutos.", text
    assert_match %r{/passwords/([^/]+)/edit}, text

    token = text.match(%r{/passwords/([^/]+)/edit})[1]
    assert_equal @user, User.find_by_password_reset_token!(token)
  end
end
