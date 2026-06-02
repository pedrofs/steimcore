class CreateStudentMedals < ActiveRecord::Migration[8.2]
  def change
    create_table :student_medals, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :student, type: :uuid, null: false, foreign_key: true
      t.string :family, null: false
      t.integer :tier, null: false
      t.integer :value_snapshot, null: false
      t.datetime :earned_at, null: false
      t.datetime :seen_at
      t.timestamps
    end

    add_index :student_medals, [ :student_id, :family, :tier ], unique: true
  end
end
