class Student::Medals::SeensController < Student::ApplicationController
  before_action :require_selected_profile
  before_action :load_medal

  # Marks a single medal seen as its celebration finishes on the Medalhas page
  # (PRD #145, slice 4). Invoked per medal — never in bulk — so closing the page
  # mid-sequence leaves the remaining medals unseen to replay on the next visit.
  # Scoped to the selected profile's own medals; the trainer view never reaches
  # here (it reads medals only).
  def create
    @medal.mark_seen!
    track "medal_seen", family: @medal.family, tier: @medal.tier
    redirect_to student_medals_path
  end

  private
    def load_medal
      @medal = Current.student.student_medals.find(params[:medal_id])
    end
end
