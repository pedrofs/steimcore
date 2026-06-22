class Student::NoProfilesController < Student::ApplicationController
  # Terminus for a Confirmed identity with zero linked Students (e.g. all
  # archived between invite and acceptance). The session stays alive; the page
  # offers only copy and a sign-out button. See PRD #108.
  def show
    track "no_profile_reached"
    render inertia: "student/home/no_profile"
  end
end
