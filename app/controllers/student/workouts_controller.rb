class Student::WorkoutsController < Student::ApplicationController
  before_action :require_selected_profile

  def index
    workouts = Student::WorkoutsView.new(Current.student).to_h[:workouts]
    track "workouts_viewed", workouts_count: workouts.size

    render inertia: "student/workouts/index", props: { workouts: workouts }
  end
end
