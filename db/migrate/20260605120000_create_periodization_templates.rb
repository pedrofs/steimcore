class CreatePeriodizationTemplates < ActiveRecord::Migration[8.2]
  def change
    create_table :periodization_templates, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.text :body_md, default: "", null: false
      t.integer :periodization_length_weeks
      t.timestamps
    end

    create_table :periodization_template_workouts, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :periodization_template,
                   type: :uuid, null: false, foreign_key: true,
                   index: { name: "index_ptw_on_periodization_template_id" }
      t.string :name, null: false
      t.integer :position, null: false
      t.jsonb :blocks, default: [], null: false
      t.timestamps
      t.index [ :periodization_template_id, :position ], name: "index_ptw_on_template_id_and_position"
    end
  end
end
