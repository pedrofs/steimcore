class StudentIdentity < ApplicationRecord
  class UnderCooldown < StandardError; end

  include Invitable

  # validations: false — a pending identity is created eagerly from Student#save
  # with no password yet; the password is set later when the student accepts the
  # setup invitation. Confirmation lives in a later slice.
  has_secure_password validations: false
  has_many :students, dependent: :nullify
  has_many :sessions, as: :authenticatable, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :password, presence: true, confirmation: true, on: :setup

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
end
