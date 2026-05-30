class Student::HomeController < Student::ApplicationController
  before_action :require_selected_profile

  def show
    render inertia: "student/home/show", props: {
      student_name: Current.student.name,
      organization_name: Current.student.organization.name
    }
  end

  private
    # The placeholder home requires a Selected profile. When the selection is
    # missing or no longer reachable (e.g. the trainer destroyed that Student
    # mid-session), bounce to the Profile chooser if any profiles remain, or to
    # the "Nenhum perfil disponível" page if none do. The session itself stays
    # alive — the identity is still authenticated. See PRD #108.
    def require_selected_profile
      return if Current.student

      if Current.student_identity.students.exists?
        redirect_to new_student_profile_selection_path
      else
        redirect_to student_no_profile_path
      end
    end
end
