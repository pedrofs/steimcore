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

    assert_match(/#a80038/i, html, "expected the wine-red brand color in the header")
    assert_match(/>SteimFit</, html, "expected the SteimFit wordmark as plain HTML text")
    assert_match(/Enviado por SteimFit/, html, "expected the muted SteimFit footer")
  end

  test "branded HTML layout uses only inline styling — no images, no style tag, no SVG" do
    mail = PasswordsMailer.reset(User.take)
    html = mail.html_part.body.to_s

    assert_no_match(/<img\b/i, html, "branded mailer must not include any <img> tags")
    assert_no_match(/<style\b/i, html, "branded mailer must not include any <style> blocks")
    assert_no_match(/<svg\b/i, html, "branded mailer must not include any inline SVG")
    assert_empty mail.attachments, "branded mailer must not attach any images"
  end

  test "branded text layout ends with the SteimFit signature" do
    mail = PasswordsMailer.reset(User.take)
    text = mail.text_part.body.to_s

    assert_match(/— SteimFit\s*\z/, text, "expected the plain-text body to end with '— SteimFit'")
  end
end
