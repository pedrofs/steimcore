class Student::WorkoutsController < Student::ApplicationController
  before_action :require_selected_profile

  def index
    render inertia: "student/workouts/index", props: {
      workouts: Student::WorkoutsView.new(Current.student).to_h[:workouts]
    }
  end
end
