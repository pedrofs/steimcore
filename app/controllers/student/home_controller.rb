class Student::HomeController < Student::ApplicationController
  before_action :require_selected_profile

  def show
    render inertia: "student/home/show", props: {
      organization_name: Current.student.organization.name,
      dashboard: Student::DashboardView.new(Current.student).to_h
    }
  end
end
