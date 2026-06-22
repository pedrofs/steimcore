class Student::SessionsController < Student::ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    track "sign_in_failed", reason: "rate_limited"
    redirect_to new_student_session_path, alert: "Tente novamente em alguns minutos."
  }

  def new
    render inertia: "student/sessions/new", props: {
      email_address: params[:email_address]
    }
  end

  def create
    if identity = StudentIdentity.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for identity
      track "signed_in", students_count: identity.students.count
      redirect_to_profile_destination
    else
      track "sign_in_failed", reason: "bad_credentials"
      redirect_to new_student_session_path(email_address: params[:email_address]),
                  inertia: { errors: { base: [ "E-mail ou senha incorretos." ] } }
    end
  end

  def destroy
    terminate_session
    redirect_to new_student_session_path, status: :see_other
  end
end
