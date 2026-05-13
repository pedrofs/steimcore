# frozen_string_literal: true

# Lifts the archived state from a Student. Idempotent — restore! is a no-op
# when the record is already unarchived.
class Students::RestorationsController < InertiaController
  before_action :load_student

  def create
    @student.restore!

    redirect_to student_path(@student), notice: "Aluno restaurado."
  end

  private
    def load_student
      @student = current_organization.students.find(params[:student_id])
    end
end
