class AddPhoneAndEmailToStudents < ActiveRecord::Migration[8.2]
  def change
    add_column :students, :phone, :string, null: true, default: nil
    add_column :students, :email, :string, null: true, default: nil

    add_index :students, :phone, unique: true, where: "phone IS NOT NULL"
    add_index :students, :email, unique: true, where: "email IS NOT NULL"
  end
end
