class AddDismissedAtToVoiceRecordings < ActiveRecord::Migration[8.2]
  def change
    add_column :voice_recordings, :dismissed_at, :datetime
  end
end
