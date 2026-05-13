class MakeCyclicFksDeferrable < ActiveRecord::Migration[8.2]
  # The student→periodization→periodization_version→voice_recording graph has
  # three cyclic FK pairs. Destroying a student transactionally cascades through
  # all of them; without deferred checks, Postgres rejects the intermediate
  # statements because the "back-pointer" still references a row that's about
  # to be deleted later in the same transaction. Marking the back-pointers
  # DEFERRABLE INITIALLY DEFERRED moves the check to COMMIT, by which point the
  # cascade is consistent.
  CYCLIC_FKS = [
    { table: :students,               column: :active_periodization_id, references: :periodizations,         fk_name: "fk_rails_students_active_periodization_id" },
    { table: :periodizations,         column: :current_version_id,      references: :periodization_versions, fk_name: "fk_rails_periodizations_current_version_id" },
    { table: :periodization_versions, column: :voice_recording_id,      references: :voice_recordings,       fk_name: "fk_rails_periodization_versions_voice_recording_id" }
  ].freeze

  def up
    CYCLIC_FKS.each do |fk|
      remove_foreign_key fk[:table], column: fk[:column]
      execute <<~SQL
        ALTER TABLE #{fk[:table]}
        ADD CONSTRAINT #{fk[:fk_name]}
        FOREIGN KEY (#{fk[:column]}) REFERENCES #{fk[:references]} (id)
        DEFERRABLE INITIALLY DEFERRED
      SQL
    end
  end

  def down
    CYCLIC_FKS.each do |fk|
      execute "ALTER TABLE #{fk[:table]} DROP CONSTRAINT #{fk[:fk_name]}"
      add_foreign_key fk[:table], fk[:references], column: fk[:column]
    end
  end
end
