class RemovePrintedAtFromPeriodizationVersions < ActiveRecord::Migration[8.2]
  def change
    remove_column :periodization_versions, :printed_at, :datetime
  end
end
