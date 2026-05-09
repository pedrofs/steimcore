class AddPeriodizationFkToStudentsAndVersions < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key :students, :periodizations, column: :active_periodization_id
    add_foreign_key :periodizations, :periodization_versions, column: :current_version_id
  end
end
