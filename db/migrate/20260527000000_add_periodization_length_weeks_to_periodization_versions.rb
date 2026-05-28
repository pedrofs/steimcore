class AddPeriodizationLengthWeeksToPeriodizationVersions < ActiveRecord::Migration[8.2]
  def change
    add_column :periodization_versions, :periodization_length_weeks, :integer
  end
end
