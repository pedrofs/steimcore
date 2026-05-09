# Idempotent seeds. Safe to re-run in any environment.
#
# Bootstraps the SteimFit organization and the partner trainer's user account.
# Trainer credentials come from Rails credentials (preferred) with environment
# variable fallbacks so nothing real is checked into the repo.

steimfit = Organization.find_or_create_by!(name: "SteimFit")

trainer_credentials = Rails.application.credentials.dig(:steimfit, :trainer) || {}
trainer_email = trainer_credentials[:email] || ENV["STEIMFIT_TRAINER_EMAIL"]
trainer_password = trainer_credentials[:password] || ENV["STEIMFIT_TRAINER_PASSWORD"]

if trainer_email.blank? || trainer_password.blank?
  Rails.logger.warn("[seeds] Skipping trainer seed: STEIMFIT_TRAINER_EMAIL/PASSWORD not set (and no credentials.steimfit.trainer entry).")
else
  user = User.find_or_initialize_by(email_address: trainer_email)
  user.organization = steimfit
  user.password = trainer_password if user.new_record? || user.password_digest.blank?
  user.save!
end
