class Student::HomeController < Student::ApplicationController
  before_action :require_selected_profile

  def show
    dashboard = Student::DashboardView.new(Current.student).to_h
    track "home_viewed",
      trained_today: dashboard[:trained_today],
      entry_state: entry_state_for(dashboard[:session_entry])

    render inertia: "student/home/show", props: {
      organization_name: Current.student.organization.name,
      dashboard: dashboard
    }
  end

  private
    # Collapses the home's session-entry payload into the single state the student
    # actually faces when they open the app — the richest usage signal we capture,
    # since it says, on every visit, whether they *could* train. An in-progress
    # session always wins (resume); otherwise a rest day, then an available start,
    # then a plan that isn't ready to train from.
    def entry_state_for(session_entry)
      return "resume" if session_entry[:active_session]
      return "rest_day" if session_entry[:rest_day]
      return "can_start" if session_entry[:can_start]

      "no_plan"
    end
end
