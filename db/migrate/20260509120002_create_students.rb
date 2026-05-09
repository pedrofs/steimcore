class CreateStudents < ActiveRecord::Migration[8.2]
  def change
    create_table :students, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :age
      t.string :sex
      t.string :primary_goal
      t.text :restrictions_summary
      t.integer :weekly_frequency
      t.text :anamnesis_md, null: false, default: ""
      t.text :notes_md, null: false, default: ""
      t.uuid :active_periodization_id
      t.datetime :archived_at

      t.timestamps
    end

    add_index :students, :archived_at
  end
end
