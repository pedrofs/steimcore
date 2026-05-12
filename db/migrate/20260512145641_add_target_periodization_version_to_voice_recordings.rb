class AddTargetPeriodizationVersionToVoiceRecordings < ActiveRecord::Migration[8.2]
  def change
    add_reference :voice_recordings, :target_periodization_version,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :periodization_versions }
  end
end
