class StudentIdentity < ApplicationRecord
  class UnderCooldown < StandardError; end

  include Invitable
  include PushNotifiable

  # validations: false — a pending identity is created eagerly from Student#save
  # with no password yet; the password is set later when the student accepts the
  # setup invitation. Confirmation lives in a later slice.
  has_secure_password validations: false
  has_many :students, dependent: :nullify
  has_many :sessions, as: :authenticatable, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :password, presence: true, confirmation: true, on: [ :setup, :password_reset ]

  generates_token_for :setup, expires_in: 30.days do
    password_digest
  end

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  # Consumes a setup invitation: sets the password (validated only in the
  # :setup context, since the eager pending identity is created without one)
  # and thereby transitions the identity to confirmed (`password_digest`
  # becomes present). See PRD #108 and the Setup acceptance glossary term.
  def complete_setup!(password:, password_confirmation:)
    self.password = password
    self.password_confirmation = password_confirmation
    save!(context: :setup)
  end

  # Resets the password from the forgot-password flow and revokes every existing
  # session for this identity (so any stale access is dropped). Validated in the
  # :password_reset context, mirroring :setup. See PRD #108, issue #116.
  def reset_password!(password:, password_confirmation:)
    self.password = password
    self.password_confirmation = password_confirmation
    transaction do
      save!(context: :password_reset)
      sessions.destroy_all
    end
  end
end
