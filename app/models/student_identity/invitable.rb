# Encapsulates the setup-invitation choreography — cooldown bookkeeping, token
# minting (deferred to the mailer view), and mailer dispatch — behind a small
# public surface so trainer-side controllers call `identity.invite!(...)` and
# ask predicates without ever touching `last_invited_at`, tokens, or the mailer
# directly. See ADR-0004 and PRD #108.
module StudentIdentity::Invitable
  extend ActiveSupport::Concern

  COOLDOWN = 24.hours

  included do
    scope :pending,   -> { where(password_digest: nil) }
    scope :confirmed, -> { where.not(password_digest: nil) }
    scope :off_cooldown, -> {
      where("last_invited_at IS NULL OR last_invited_at <= ?", COOLDOWN.ago)
    }
    scope :invitable, -> { pending.off_cooldown }
  end

  class_methods do
    # The pending-identity cohort the trainer can invite: identities not yet
    # confirmed, linked to at least one unarchived student with an email in the
    # given organization. Includes under-cooldown identities — the bulk trigger
    # skips those at send time (invite! raises), keeping the cohort definition
    # stable while the off_cooldown scope narrows it to who'll actually receive.
    def pending_for_organization(organization)
      pending
        .joins(:students)
        .where(students: { organization: organization, archived_at: nil })
        .where.not(students: { email: [ nil, "" ] })
        .distinct
    end
  end

  # No-op when already confirmed; raises StudentIdentity::UnderCooldown when a
  # prior invite is still within the cooldown window. Otherwise stamps
  # last_invited_at and enqueues the setup mailer in the same transaction. The
  # setup token is minted lazily by the mailer view.
  def invite!(from_organization:)
    return if confirmed?
    raise StudentIdentity::UnderCooldown if under_cooldown?

    transaction do
      update!(last_invited_at: Time.current)
      StudentIdentityMailer.setup_invitation(self, organization: from_organization).deliver_later
    end
  end

  def invitable?
    !confirmed? && !under_cooldown?
  end

  def confirmed?
    password_digest.present?
  end

  def under_cooldown?
    last_invited_at.present? && last_invited_at > COOLDOWN.ago
  end

  def cooldown_available_at
    last_invited_at && last_invited_at + COOLDOWN
  end
end
