class Student
  # Read-only payload for the student-facing live session screen
  # (Student::TrainingSessionsController#show). Mirrors the snapshot fields the
  # trainer board exposes per session, scoped to a single student's session.
  # Block toggling/finish/cancel arrive in later slices (#140/#141); this slice
  # just renders the started session.
  class LiveSessionView
    def initialize(session)
      @session = session
    end

    def to_h
      {
        id: @session.id,
        workout_name: @session.workout_name_snapshot,
        workout_position: @session.workout_position_snapshot,
        blocks: @session.blocks_snapshot,
        completed_block_indices: @session.progress,
        finished_at: @session.finished_at,
        initiator: @session.student_initiated? ? "student" : "trainer"
      }
    end
  end
end
