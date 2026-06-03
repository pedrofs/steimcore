class ApplicationMailer < ActionMailer::Base
  # The full SteimFit logo lockup (hexagon mark + wordmark), embedded inline so
  # the brand renders in the header without the recipient having to unblock
  # remote images. Rasterised from public/steimfit-lockup.svg.
  LOGO_FILENAME = "steimfit-lockup.png".freeze
  LOGO_PATH = Rails.root.join("public/steimfit-lockup.png").freeze

  default from: "#{MailerHelper::BRAND_NAME} <no-reply@steimfit.com>"
  layout "mailer"
  helper MailerHelper

  before_action :embed_brand_logo

  private
    def embed_brand_logo
      attachments.inline[LOGO_FILENAME] = LOGO_PATH.read
    end
end
