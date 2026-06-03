# Preview all emails at http://localhost:3000/rails/mailers/student_identity_mailer
class StudentIdentityMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/student_identity_mailer/setup_invitation
  def setup_invitation
    identity = StudentIdentity.first
    organization = identity.students.first&.organization || Organization.first
    StudentIdentityMailer.setup_invitation(identity, organization: organization)
  end

  # Preview this email at http://localhost:3000/rails/mailers/student_identity_mailer/password_reset
  def password_reset
    StudentIdentityMailer.password_reset(StudentIdentity.first)
  end
end
