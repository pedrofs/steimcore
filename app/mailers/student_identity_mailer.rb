class StudentIdentityMailer < ApplicationMailer
  def setup_invitation(student_identity, organization:)
    @organization = organization
    # The setup token is minted lazily here, per the Invitable contract.
    @setup_url = edit_student_setup_acceptance_url(student_identity.generate_token_for(:setup))

    mail(
      to: student_identity.email_address,
      subject: "Você foi convidado(a) para o #{@organization.name}"
    )
  end
end
