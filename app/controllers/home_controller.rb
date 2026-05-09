# frozen_string_literal: true

class HomeController < InertiaController
  with_title "Home"
  with_breadcrumb label: "Home", path: -> { root_path }

  def index
    render inertia: {}
  end
end
