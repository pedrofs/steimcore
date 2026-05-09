class CreatePeriodizations < ActiveRecord::Migration[8.2]
  def change
    create_table :periodizations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :student, type: :uuid, null: false, foreign_key: true
      t.uuid :current_version_id
      t.datetime :archived_at

      t.timestamps
    end

    add_index :periodizations, [ :student_id, :archived_at ]
  end
end
