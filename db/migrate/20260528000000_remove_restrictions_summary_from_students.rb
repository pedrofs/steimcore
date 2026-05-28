class RemoveRestrictionsSummaryFromStudents < ActiveRecord::Migration[8.2]
  def change
    remove_column :students, :restrictions_summary, :text
  end
end
