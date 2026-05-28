class AddNotesMdToOrganizations < ActiveRecord::Migration[8.2]
  def change
    add_column :organizations, :notes_md, :text, null: false, default: ""
  end
end
