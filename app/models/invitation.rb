class Invitation < ApplicationRecord
  class EmailAlreadyTaken < StandardError; end

  belongs_to :organization
  belongs_to :invited_by, class_name: "User"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email_address, uniqueness: {
    scope: :organization_id,
    conditions: -> { where(accepted_at: nil) },
    case_sensitive: false,
    message: "Já existe um convite pendente para esse e-mail."
  }, on: :create
  validate :email_must_not_belong_to_org_member, on: :create
  validate :email_must_not_exist_in_users_elsewhere, on: :create

  generates_token_for :acceptance, expires_in: 7.days do
    updated_at.to_fs(:iso8601)
  end

  def expired?
    created_at < 7.days.ago
  end

  def accept!(password:, password_confirmation:)
    user = nil
    transaction do
      user = organization.users.create!(
        email_address: email_address,
        password: password,
        password_confirmation: password_confirmation
      )
      update!(accepted_at: Time.current)
    end
    user
  rescue ActiveRecord::RecordNotUnique
    raise EmailAlreadyTaken
  end

  private
    def email_must_not_belong_to_org_member
      return if email_address.blank? || organization.nil?
      return unless organization.users.exists?(email_address: email_address)

      errors.add(:email_address, "Esse e-mail já é um membro da organização.")
    end

    def email_must_not_exist_in_users_elsewhere
      return if email_address.blank?

      scope = User.where(email_address: email_address)
      scope = scope.where.not(organization_id: organization_id) if organization_id
      return unless scope.exists?

      errors.add(:email_address, "E-mail já está em uso.")
    end
end
