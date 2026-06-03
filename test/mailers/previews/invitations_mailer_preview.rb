# Preview all emails at http://localhost:3000/rails/mailers/invitations_mailer
class InvitationsMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/invitations_mailer/invite
  def invite
    invitation = Invitation.order(:created_at).last || Invitation.new(
      email_address: "convidado@example.com",
      organization: Organization.first,
      invited_by: User.first
    )
    InvitationsMailer.invite(invitation)
  end
end
