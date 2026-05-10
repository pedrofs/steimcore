class ReplaceWorkoutContentMdWithBlocks < ActiveRecord::Migration[8.2]
  def change
    add_column :workouts, :blocks, :jsonb, null: false, default: []
    remove_column :workouts, :content_md, :text, default: "", null: false
  end
end
