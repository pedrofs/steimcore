class DropUniqueEmailIndexOnStudents < ActiveRecord::Migration[8.2]
  def change
    remove_index :students, :email
    add_index :students, :email, where: "email IS NOT NULL"
  end
end
