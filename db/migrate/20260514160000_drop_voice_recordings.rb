class DropVoiceRecordings < ActiveRecord::Migration[8.2]
  # Voice recording subsystem is gone (issue #69). Drops the FK from
  # periodization_versions, the voice_recording_id column, and the
  # voice_recordings table.
  def up
    remove_foreign_key :periodization_versions, column: :voice_recording_id, name: "fk_rails_periodization_versions_voice_recording_id"
    remove_index :periodization_versions, :voice_recording_id if index_exists?(:periodization_versions, :voice_recording_id)
    remove_column :periodization_versions, :voice_recording_id
    drop_table :voice_recordings
  end

  def down
    create_table :voice_recordings, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.datetime :dismissed_at
      t.text :error_message
      t.string :kind, null: false
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.text :proposed_anamnesis_md
      t.string :status, null: false
      t.references :student, type: :uuid, null: false, foreign_key: true
      t.uuid :target_periodization_version_id
      t.uuid :target_workout_id
      t.bigint :trainer_id, null: false
      t.text :transcript, default: "", null: false
      t.datetime :transcript_edited_at
      t.timestamps

      t.index [ :status, :created_at ]
      t.index [ :student_id, :created_at ]
      t.index :target_periodization_version_id
      t.index :target_workout_id
      t.index :trainer_id
    end

    add_foreign_key :voice_recordings, :periodization_versions, column: :target_periodization_version_id
    add_foreign_key :voice_recordings, :users, column: :trainer_id
    add_foreign_key :voice_recordings, :workouts, column: :target_workout_id

    add_reference :periodization_versions, :voice_recording, type: :uuid, index: true
    execute <<~SQL
      ALTER TABLE periodization_versions
      ADD CONSTRAINT fk_rails_periodization_versions_voice_recording_id
      FOREIGN KEY (voice_recording_id) REFERENCES voice_recordings (id)
      DEFERRABLE INITIALLY DEFERRED
    SQL
  end
end
