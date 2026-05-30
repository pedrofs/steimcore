class StudentIdentityMailer < ApplicationMailer
  def setup_invitation(student_identity, organization:)
    @organization = organization
    # The /student/setup_acceptances route ships in a later slice; until then
    # this link 404s. Built as a string because the route helper does not exist
    # yet. The setup token is minted lazily here, per the Invitable contract.
    @setup_url = "#{root_url}student/setup_acceptances/#{student_identity.generate_token_for(:setup)}"

    mail(
      to: student_identity.email_address,
      subject: "Você foi convidado(a) para o #{@organization.name}"
    )
  end
end
