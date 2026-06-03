require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  test "default from address is the SteimFit no-reply" do
    assert_equal "SteimFit <no-reply@steimfit.com>", ApplicationMailer.default[:from]
  end

  test "no reply_to is set globally" do
    assert_nil ApplicationMailer.default[:reply_to]
  end

  test "branded HTML layout wraps every mailer body" do
    mail = PasswordsMailer.reset(User.take)
    html = mail.html_part.body.to_s

    assert_match(/#a80038/i, html, "expected the wine-red brand color in the layout")
    assert_match(/Enviado por <strong[^>]*>SteimFit/, html, "expected the muted SteimFit footer")
  end

  test "branded HTML layout embeds the logo lockup as an inline attachment" do
    mail = PasswordsMailer.reset(User.take)
    html = mail.html_part.body.to_s

    assert_match(/<img\b/i, html, "expected the brand logo as an <img> tag")

    logo = mail.attachments.inline["steimfit-lockup.png"]
    assert_not_nil logo, "expected the logo lockup attached inline"
    assert_equal "image/png", logo.mime_type
    assert html.include?(logo.url), "expected the layout to reference the inline logo by its CID url"
  end

  test "branded HTML layout uses only inline styling — no <style> blocks, no inline SVG" do
    mail = PasswordsMailer.reset(User.take)
    html = mail.html_part.body.to_s

    assert_no_match(/<style\b/i, html, "branded mailer must not include any <style> blocks")
    assert_no_match(/<svg\b/i, html, "branded mailer must not include any inline SVG")
  end

  test "branded text layout ends with the SteimFit signature" do
    mail = PasswordsMailer.reset(User.take)
    text = mail.text_part.body.to_s

    assert_match(/— SteimFit\s*\z/, text, "expected the plain-text body to end with '— SteimFit'")
  end
end
