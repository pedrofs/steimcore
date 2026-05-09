class CreatePeriodizationVersions < ActiveRecord::Migration[8.2]
  def change
    create_table :periodization_versions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :periodization, type: :uuid, null: false, foreign_key: true
      t.references :parent_version, type: :uuid, null: true, foreign_key: { to_table: :periodization_versions }
      t.references :trainer, type: :bigint, null: false, foreign_key: { to_table: :users }
      t.references :voice_recording, type: :uuid, null: true, foreign_key: true
      t.text :body_md, null: false, default: ""
      t.string :status, null: false
      t.text :error_message

      t.timestamps
    end

    add_index :periodization_versions, [ :periodization_id, :created_at ]
  end
end
