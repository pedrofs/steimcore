class Student::ApplicationController < InertiaController
  authenticates_as StudentIdentity

  inertia_share can_switch_profile: -> {
    identity = Current.student_identity
    identity.present? && identity.students.count >= 2
  }

  private
    def unauthenticated_redirect_path
      new_student_session_path
    end

    def web_push_subscription_path
      student_push_subscription_path
    end

    # Pages that act on the Selected profile require one to be set. When the
    # selection is missing or no longer reachable (e.g. the trainer destroyed
    # that Student mid-session), bounce to the Profile chooser if any profiles
    # remain, or to the "Nenhum perfil disponível" page if none do. The session
    # itself stays alive — the identity is still authenticated. See PRD #108.
    def require_selected_profile
      return if Current.student

      if Current.student_identity.students.exists?
        redirect_to new_student_profile_selection_path
      else
        redirect_to student_no_profile_path
      end
    end

    # Three-branch routing shared by sign-in (`Student::SessionsController`) and
    # setup acceptance (`Student::SetupAcceptancesController`): zero profiles →
    # the "Nenhum perfil disponível" page; exactly one → auto-select it and land
    # on the placeholder home; two or more → force a fresh choice in the Profile
    # chooser (no remembered default). See PRD #108.
    def redirect_to_profile_destination
      students = Current.student_identity.students

      case students.count
      when 0
        redirect_to student_no_profile_path
      when 1
        Current.session.update!(selected_student: students.first)
        redirect_to student_home_path
      else
        redirect_to new_student_profile_selection_path
      end
    end
end
