class AddSelectedStudentIdToSessions < ActiveRecord::Migration[8.2]
  def change
    add_column :sessions, :selected_student_id, :uuid
    add_index :sessions, :selected_student_id
    add_foreign_key :sessions, :students, column: :selected_student_id, on_delete: :nullify
  end
end
