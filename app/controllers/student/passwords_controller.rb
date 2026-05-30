class Student::PasswordsController < Student::ApplicationController
  allow_unauthenticated_access
  before_action :set_identity_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_student_password_path, alert: "Tente novamente em alguns minutos." }

  def new
    render inertia: "student/passwords/new", props: {
      email_address: params[:email_address]
    }
  end

  def create
    if identity = StudentIdentity.find_by(email_address: params[:email_address])
      StudentIdentityMailer.password_reset(identity).deliver_later
    end

    redirect_to new_student_session_path, notice: "Se houver uma conta com esse e-mail, enviamos instruções para redefinir a senha."
  end

  def edit
    render inertia: "student/passwords/edit", props: { token: params[:token] }
  end

  def update
    @identity.reset_password!(
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )
    redirect_to new_student_session_path, notice: "Senha redefinida."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_student_password_path(params[:token]),
                inertia: { errors: e.record.errors.to_hash(true) }
  end

  private
    def set_identity_by_token
      @identity = StudentIdentity.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_student_password_path, alert: "O link de redefinição é inválido ou expirou."
    end
end
