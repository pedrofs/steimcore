# frozen_string_literal: true

class InvitationAcceptancesController < InertiaController
  allow_unauthenticated_access
  before_action :set_invitation_by_token, only: %i[ edit update ]
  before_action :ensure_not_yet_accepted, only: %i[ edit update ]

  def edit
    render inertia: "invitation_acceptances/edit", props: {
      token: params[:token],
      email_address: @invitation.email_address,
      organization_name: @invitation.organization.name
    }
  end

  def update
    user = @invitation.accept!(
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )
    start_new_session_for(user)
    redirect_to root_path, notice: "Bem-vindo(a), #{user.email_address}!"
  rescue Invitation::EmailAlreadyTaken
    redirect_to edit_invitation_acceptance_path(params[:token]),
                inertia: { errors: { email_address: [ "E-mail já está em uso." ] } }
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_invitation_acceptance_path(params[:token]),
                inertia: { errors: e.record.errors.to_hash(true) }
  end

  private
    def set_invitation_by_token
      @invitation = Invitation.find_by_token_for!(:acceptance, params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to new_session_path, alert: "Este convite não é mais válido."
    end

    def ensure_not_yet_accepted
      return if @invitation.nil? || @invitation.accepted_at.nil?

      redirect_to new_session_path, alert: "Este convite não é mais válido."
    end
end
