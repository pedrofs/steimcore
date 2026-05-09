class RegistrationsController < InertiaController
  allow_unauthenticated_access

  def new
    render inertia: "registrations/new", props: {
      email_address: params[:email_address]
    }
  end

  def create
    user = User.new(registration_params)
    if user.save
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_registration_path(email_address: params[:email_address]),
                  inertia: { errors: user.errors.to_hash(true) }
    end
  end

  private
    def registration_params
      params.permit(:email_address, :password, :password_confirmation)
    end
end
