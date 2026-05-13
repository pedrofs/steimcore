# frozen_string_literal: true

class Invitations::DeliveriesController < InertiaController
  before_action :load_invitation

  def create
    @invitation.touch
    InvitationsMailer.invite(@invitation).deliver_later
    redirect_to organization_path, notice: "Convite reenviado para #{@invitation.email_address}."
  end

  private
    def load_invitation
      @invitation = current_organization.invitations.find(params[:invitation_id])
    end
end
