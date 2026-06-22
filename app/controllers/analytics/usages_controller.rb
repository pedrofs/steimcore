# frozen_string_literal: true

# "Uso dos alunos" tab of the trainer Analytics section: how this organization's
# students actually use the app, derived from the student-app ahoy event stream.
# The metrics live on Organization::UsageAnalytics.
class Analytics::UsagesController < InertiaController
  with_breadcrumb label: "Analytics", path: -> { analytics_path }

  def show
    @title = "Analytics"

    render inertia: "analytics/usages/show", props: Organization::UsageAnalytics.new(current_organization).to_h
  end
end
