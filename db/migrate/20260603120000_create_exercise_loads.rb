class CreateExerciseLoads < ActiveRecord::Migration[8.2]
  def change
    create_table :exercise_loads, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :student, type: :uuid, null: false, foreign_key: true
      t.references :training_session, type: :uuid, null: true, foreign_key: { on_delete: :nullify }

      # +exercise_key+ is the normalized movement name (the stable identity weight
      # is keyed by, since block items carry no id). +exercise_name+ keeps the
      # display name as it was entered. +value+ is freeform (e.g. "60kg",
      # "20kg/lado", "peso do corpo").
      t.string :exercise_key, null: false
      t.string :exercise_name, null: false
      t.string :value, null: false

      t.timestamps
    end

    # Latest load per (student, movement). UUIDv7 PKs sort chronologically, so a
    # DISTINCT ON (exercise_key) ORDER BY id DESC over this index yields the most
    # recent value per movement.
    add_index :exercise_loads, [ :student_id, :exercise_key, :id ], order: { id: :desc },
              name: "index_exercise_loads_on_student_key_id"
  end
end
