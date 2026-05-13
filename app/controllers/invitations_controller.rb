# frozen_string_literal: true

class InvitationsController < InertiaController
  with_title "Novo convite"

  before_action :load_invitation, only: :destroy

  def new
    render inertia: "invitations/new", props: {
      email_address: params[:email_address]
    }
  end

  def create
    @invitation = current_organization.invitations.new(
      email_address: params[:email_address],
      invited_by: Current.user
    )

    if @invitation.save
      InvitationsMailer.invite(@invitation).deliver_later
      redirect_to organization_path, notice: "Convite enviado para #{@invitation.email_address}."
    else
      redirect_to new_invitation_path(email_address: params[:email_address]),
                  inertia: { errors: @invitation.errors.to_hash(true) }
    end
  end

  def destroy
    @invitation.destroy!
    redirect_to organization_path, notice: "Convite revogado."
  end

  private
    def load_invitation
      @invitation = current_organization.invitations.find(params[:id])
    end
end
