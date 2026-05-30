class Student::HomeController < Student::ApplicationController
  # Single-profile only in this slice: the profile chooser and the proper
  # Current.student derivation land in #114/#115. Until then the placeholder
  # home shows the first (and, in this slice, only) linked Student.
  def show
    student = Current.student_identity.students.first

    render inertia: "student/home/show", props: {
      student_name: student&.name,
      organization_name: student&.organization&.name
    }
  end
end
