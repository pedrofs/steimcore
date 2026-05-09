class AddTargetWorkoutToVoiceRecordings < ActiveRecord::Migration[8.2]
  def change
    add_reference :voice_recordings, :target_workout, type: :uuid, null: true, foreign_key: { to_table: :workouts }
  end
end
