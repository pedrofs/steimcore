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

  generates_token_for :setup, expires_in: 30.days do
    password_digest
  end

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end
end
