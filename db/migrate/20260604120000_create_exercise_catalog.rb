class CreateExerciseCatalog < ActiveRecord::Migration[8.2]
  def change
    create_table :exercise_families, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :name, null: false
      t.string :normalized_key, null: false, index: { unique: true }
      t.timestamps
    end

    create_table :exercise_muscle_groups, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :name, null: false
      t.string :normalized_key, null: false, index: { unique: true }
      t.timestamps
    end

    create_table :exercises, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :name, null: false
      t.string :state, null: false, default: "unenriched"
      t.references :exercise_family, type: :uuid, null: true, foreign_key: true
      t.references :muscle_group, type: :uuid, null: true,
                   foreign_key: { to_table: :exercise_muscle_groups }
      t.references :merged_into, type: :uuid, null: true,
                   foreign_key: { to_table: :exercises }
      t.timestamps
    end

    create_table :exercise_aliases, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :exercise, type: :uuid, null: false, foreign_key: true
      t.string :raw_name, null: false
      t.string :normalized_key, null: false, index: { unique: true }
      t.string :source, null: false, default: "primary"
      t.float :confidence, null: true
      t.timestamps
    end
  end
end
