# frozen_string_literal: true

class HomeController < InertiaController
  allow_unauthenticated_access only: :index
  with_title "Home"
  with_breadcrumb label: "Home", path: -> { root_path }

  def index
    return render_landing unless authenticated?

    render inertia: {
      queue: Organization::DashboardQueue.new(current_organization).to_h,
      total_students: current_organization.students.unarchived.count
    }
  end

  private
    # Unauthenticated visitors land on the choice page that routes them to the
    # trainer or student sign-in flow instead of being forced straight into the
    # trainer login.
    def render_landing
      render inertia: "home/landing"
    end
end
