class CreateWorkouts < ActiveRecord::Migration[8.2]
  def change
    create_table :workouts, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :periodization_version, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.text :content_md, null: false, default: ""
      t.integer :position, null: false

      t.timestamps
    end

    add_index :workouts, [ :periodization_version_id, :position ]
  end
end
