# frozen_string_literal: true

# Archives a student with an optional short reason — the reason is shown on
# the archived banner so the coach remembers why the student was set aside
# (e.g. only attends crossfit, not weightlifting).
class Students::ArchivesController < InertiaController
  before_action :load_student
  before_action :ensure_not_already_archived

  def create
    @student.archive!(reason: archive_params[:reason])

    redirect_to student_path(@student), notice: "Aluno arquivado."
  end

  private
    def load_student
      @student = current_organization.students.find(params[:student_id])
    end

    def ensure_not_already_archived
      return unless @student.archived?

      redirect_to student_path(@student), alert: "Aluno já está arquivado."
    end

    def archive_params
      params.fetch(:archive, {}).permit(:reason)
    end
end
