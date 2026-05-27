class AddArchiveReasonToStudents < ActiveRecord::Migration[8.2]
  def change
    add_column :students, :archive_reason, :string
  end
end
