class Student::ApplicationController < InertiaController
  authenticates_as StudentIdentity

  private
    def unauthenticated_redirect_path
      new_student_session_path
    end
end
