class ReplaceAgeWithBirthdayOnStudents < ActiveRecord::Migration[8.2]
  def change
    remove_column :students, :age, :integer
    add_column :students, :birthday, :date
  end
end
