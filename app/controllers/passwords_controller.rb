class PasswordsController < InertiaController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "Tente novamente em alguns minutos." }

  def new
    render inertia: "passwords/new", props: {
      email_address: params[:email_address]
    }
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: "Se houver uma conta com esse e-mail, enviamos instruções para redefinir a senha."
  end

  def edit
    render inertia: "passwords/edit", props: { token: params[:token] }
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Senha redefinida."
    else
      redirect_to edit_password_path(params[:token]),
                  inertia: { errors: @user.errors.to_hash(true) }
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "O link de redefinição é inválido ou expirou."
    end
end
