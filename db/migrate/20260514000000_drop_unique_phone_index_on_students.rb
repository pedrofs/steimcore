class DropUniquePhoneIndexOnStudents < ActiveRecord::Migration[8.2]
  def change
    remove_index :students, :phone
    add_index :students, :phone, where: "phone IS NOT NULL"
  end
end
