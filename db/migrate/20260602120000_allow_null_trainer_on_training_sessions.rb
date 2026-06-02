class AllowNullTrainerOnTrainingSessions < ActiveRecord::Migration[8.2]
  def up
    change_column_null :training_sessions, :trainer_id, true
  end

  def down
    change_column_null :training_sessions, :trainer_id, false
  end
end
