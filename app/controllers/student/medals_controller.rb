class Student::MedalsController < Student::ApplicationController
  before_action :require_selected_profile

  def index
    track "medals_viewed", unseen_count: Current.student.student_medals.unseen.count

    render inertia: "student/medals/index", props: {
      **Student::MedalsView.new(Current.student).to_h
    }
  end
end
