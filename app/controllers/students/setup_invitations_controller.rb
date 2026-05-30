# frozen_string_literal: true

class Students::SetupInvitationsController < InertiaController
  before_action :load_student
  before_action :ensure_email_present
  before_action :ensure_not_confirmed

  def create
    @student.student_identity.invite!(from_organization: current_organization)
    redirect_to student_path(@student), notice: "Convite enviado para #{@student.email}."
  rescue StudentIdentity::UnderCooldown
    redirect_to student_path(@student),
                alert: "Esse aluno já foi convidado nas últimas 24 horas. Tente novamente mais tarde."
  end

  private
    def load_student
      @student = current_organization.students.find(params[:student_id])
    end

    def ensure_email_present
      return if @student.email.present?

      redirect_to student_path(@student),
                  alert: "Cadastre um e-mail para o aluno antes de enviar o convite."
    end

    def ensure_not_confirmed
      return unless @student.student_identity&.confirmed?

      redirect_to student_path(@student), alert: "Esse aluno já tem acesso ao app."
    end
end
