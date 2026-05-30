class AddStudentIdentityToStudents < ActiveRecord::Migration[8.2]
  def change
    add_reference :students, :student_identity, type: :uuid, null: true, foreign_key: true, index: true
  end
end
