class InvitationsMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @organization = invitation.organization
    @inviter = invitation.invited_by
    @token = invitation.generate_token_for(:acceptance)

    mail(
      to: invitation.email_address,
      subject: "Você foi convidado(a) para o #{@organization.name}"
    )
  end
end
