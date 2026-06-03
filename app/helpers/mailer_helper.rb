module MailerHelper
  # Canonical brand identity for transactional emails. Reuses the web app's
  # brand tokens (see app/frontend/lib/brand.ts and the --brand CSS variable):
  # the wine-red mark colour, the "SteimFit" wordmark, and the tagline.
  BRAND_NAME = "SteimFit".freeze
  BRAND_TAGLINE = "Treinamento personalizado".freeze
  BRAND_COLOR = "#a80038".freeze
  BRAND_FONT = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif".freeze

  # The full logo lockup (hexagon mark + wordmark), embedded as an inline (CID)
  # attachment by ApplicationMailer so it renders without the recipient
  # unblocking remote images. The source PNG is 320×132; we render it at 107×44.
  def brand_logo(height: 44)
    width = (height * 320.0 / 132).round
    image_tag attachments[ApplicationMailer::LOGO_FILENAME].url,
              width: width, height: height, alt: BRAND_NAME,
              style: "display:block;border:0;outline:none;text-decoration:none;width:#{width}px;height:#{height}px;"
  end

  # Primary call-to-action button in the brand colour.
  def brand_button(label, url)
    link_to label, url,
            style: "display:inline-block;background-color:#{BRAND_COLOR};color:#ffffff;" \
                   "padding:13px 22px;text-decoration:none;font-weight:600;border-radius:6px;" \
                   "font-size:16px;line-height:1;"
  end

  # Inline text link in the brand colour, for prose that links mid-sentence.
  def brand_link(label, url)
    link_to label, url,
            style: "color:#{BRAND_COLOR};font-weight:600;text-decoration:underline;"
  end
end
