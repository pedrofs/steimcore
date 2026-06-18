# frozen_string_literal: true

class StudentSetupInvitationBatchesController < InertiaController
  def create
    sent = 0
    waiting = 0

    StudentIdentity.pending_for_organization(current_organization).each do |identity|
      identity.invite!(from_organization: current_organization)
      sent += 1
    rescue StudentIdentity::UnderCooldown
      waiting += 1
    end

    redirect_to students_path, notice: batch_notice(sent, waiting)
  end

  private
    def batch_notice(sent, waiting)
      parts = [ "#{sent} #{sent == 1 ? "convite enviado" : "convites enviados"}." ]
      if waiting.positive?
        parts << "#{waiting} #{waiting == 1 ? "aguardando" : "aguardando"} o período de espera de 1h."
      end
      parts.join(" ")
    end
end
