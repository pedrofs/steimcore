# frozen_string_literal: true

class HomeController < InertiaController
  with_title "Home"
  with_breadcrumb label: "Home", path: -> { root_path }

  def index
    render inertia: {
      queue: Organization::DashboardQueue.new(current_organization).to_h,
      print_queue: Organization::PrintQueue.new(current_organization).to_h,
      total_students: current_organization.students.unarchived.count
    }
  end
end
