# frozen_string_literal: true

# Trainer-facing Analytics section. A singular resource (one dashboard for the
# current organization); the metrics live on Organization::Analytics so the
# section can grow without fattening this controller.
class AnalyticsController < InertiaController
  with_breadcrumb label: "Analytics", path: -> { analytics_path }

  def show
    @title = "Analytics"

    render inertia: "analytics/show", props: Organization::Analytics.new(current_organization).to_h
  end
end
