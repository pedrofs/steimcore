# Encapsulates the setup-invitation choreography — cooldown bookkeeping, token
# minting (deferred to the mailer view), and mailer dispatch — behind a small
# public surface so trainer-side controllers call `identity.invite!(...)` and
# ask predicates without ever touching `last_invited_at`, tokens, or the mailer
# directly. See ADR-0004 and PRD #108.
module StudentIdentity::Invitable
  extend ActiveSupport::Concern

  COOLDOWN = 24.hours

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
