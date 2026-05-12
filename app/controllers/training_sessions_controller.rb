# frozen_string_literal: true

class TrainingSessionsController < InertiaController
  with_title "Sessões ao vivo"

  def index
    render inertia: "training_sessions/index", props: {
      training_sessions: [],
      picker_candidates: [],
      scope: "trainer"
    }
  end
end
