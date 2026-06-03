# Write side of per-exercise weight tracking: the trainer/student sets a
# movement's weight during a live session. The load belongs to the student (it
# persists across sessions); the session is recorded as provenance.
module TrainingSession::ExerciseLoadable
  extend ActiveSupport::Concern

  # Records (or re-records) the weight for a movement in this session. Each call
  # appends a new ExerciseLoad; the most recent is what future sessions read.
  def record_load!(exercise_name:, value:)
    student.exercise_loads.create!(
      training_session: self,
      exercise_name: exercise_name,
      exercise_key: ExerciseLoad.normalize_name(exercise_name),
      value: value
    )
  end

  # The session's frozen +blocks_snapshot+ enriched with the student's current
  # weight per movement. Exercise blocks and group items gain a +weight+ key
  # (nil when never set); freeform blocks pass through untouched.
  def blocks_with_loads
    loads = student.current_loads

    blocks_snapshot.map do |block|
      case block["kind"]
      when "exercise"
        block.merge("weight" => load_value(loads, block["name"]))
      when "group"
        block.merge("items" => Array(block["items"]).map { |item|
          item.merge("weight" => load_value(loads, item["name"]))
        })
      else
        block
      end
    end
  end

  private
    def load_value(loads, name)
      loads[ExerciseLoad.normalize_name(name)]&.value
    end
end
