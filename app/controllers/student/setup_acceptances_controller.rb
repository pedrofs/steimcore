class Student::SetupAcceptancesController < Student::ApplicationController
  allow_unauthenticated_access
  before_action :set_identity_by_token, only: %i[ edit update ]
  before_action :ensure_not_yet_confirmed, only: %i[ edit update ]

  def edit
    track "setup_opened", student_identity_id: @identity.id
    render inertia: "student/setup_acceptances/edit", props: {
      token: params[:token],
      email_address: @identity.email_address
    }
  end

  def update
    @identity.complete_setup!(
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )
    start_new_session_for(@identity)
    track "setup_completed", student_identity_id: @identity.id
    flash[:notice] = "Bem-vindo(a), #{@identity.email_address}!"
    redirect_to_profile_destination
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_student_setup_acceptance_path(params[:token]),
                inertia: { errors: e.record.errors.to_hash(true) }
  end

  private
    def set_identity_by_token
      @identity = StudentIdentity.find_by_token_for!(:setup, params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to new_student_session_path, alert: "Este convite não é mais válido."
    end

    def ensure_not_yet_confirmed
      return if @identity.nil? || @identity.password_digest.nil?

      redirect_to new_student_session_path, alert: "Este convite não é mais válido."
    end
end
