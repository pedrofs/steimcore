class AddPeriodizationVersionSnapshotToTrainingSessions < ActiveRecord::Migration[8.2]
  def up
    add_reference :training_sessions, :periodization_version,
                  type: :uuid,
                  null: true,
                  foreign_key: { on_delete: :nullify }

    execute <<~SQL
      UPDATE training_sessions ts
      SET periodization_version_id = w.periodization_version_id
      FROM workouts w
      WHERE ts.workout_id = w.id
    SQL
  end

  def down
    remove_reference :training_sessions, :periodization_version, foreign_key: true
  end
end
