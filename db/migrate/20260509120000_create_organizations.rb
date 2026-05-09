class CreateOrganizations < ActiveRecord::Migration[8.2]
  def change
    create_table :organizations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :name, null: false
      t.text :equipment_list_md, null: false, default: ""

      t.timestamps
    end
  end
end
