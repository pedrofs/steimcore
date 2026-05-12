class CreateTrainingSessions < ActiveRecord::Migration[8.2]
  def change
    create_table :training_sessions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :student, type: :uuid, null: false, foreign_key: true, index: false
      t.references :trainer, type: :bigint, null: false, foreign_key: { to_table: :users }, index: false
      t.references :workout, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :workout_name_snapshot, null: false
      t.integer :workout_position_snapshot, null: false
      t.jsonb :blocks_snapshot, null: false, default: []
      t.jsonb :progress, null: false, default: []
      t.datetime :finished_at

      t.timestamps
    end

    add_index :training_sessions, [ :trainer_id, :finished_at ]
    add_index :training_sessions, [ :student_id, :finished_at ]
    add_index :training_sessions, :student_id,
              unique: true,
              where: "finished_at IS NULL",
              name: "idx_one_active_training_session_per_student"
  end
end
