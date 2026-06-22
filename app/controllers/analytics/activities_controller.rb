# frozen_string_literal: true

# "Atividade" tab of the trainer Analytics section: org-level activity counts
# (training sessions and periodizations per day) from the domain tables. The
# metrics live on Organization::Analytics so the section can grow without
# fattening this controller.
class Analytics::ActivitiesController < InertiaController
  with_breadcrumb label: "Analytics", path: -> { analytics_path }

  def show
    @title = "Analytics"

    render inertia: "analytics/activities/show", props: Organization::Analytics.new(current_organization).to_h
  end
end
