class Student::ProfileSelectionsController < Student::ApplicationController
  before_action :load_selected_student, only: :create

  def new
    render inertia: "student/profile_selections/new", props: {
      students: Current.student_identity.students.map { |student|
        {
          id: student.id,
          name: student.name,
          organization_name: student.organization.name
        }
      }
    }
  end

  def create
    Current.session.update!(selected_student: @student)
    redirect_to student_home_path
  end

  private
    # The chosen Student must belong to the signed-in identity — a student_id
    # outside `identity.students` is rejected, so a tampered selection can't
    # leak another person's profile onto this session.
    def load_selected_student
      @student = Current.student_identity.students.find_by(id: params[:student_id])
      return if @student

      redirect_to new_student_profile_selection_path, alert: "Perfil inválido."
    end
end
