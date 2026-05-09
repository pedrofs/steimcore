class CreateVoiceRecordings < ActiveRecord::Migration[8.2]
  def change
    create_table :voice_recordings, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :student, type: :uuid, null: false, foreign_key: true
      t.references :trainer, null: false, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.text :transcript, null: false, default: ""
      t.datetime :transcript_edited_at
      t.text :proposed_anamnesis_md
      t.string :status, null: false
      t.text :error_message

      t.timestamps
    end

    add_index :voice_recordings, [ :student_id, :created_at ]
    add_index :voice_recordings, [ :status, :created_at ]
  end
end
