class AddPrintedAtToPeriodizationVersions < ActiveRecord::Migration[8.2]
  def change
    add_column :periodization_versions, :printed_at, :datetime
  end
end
