class MakeParentVersionFkDeferrable < ActiveRecord::Migration[8.2]
  # PeriodizationVersion has a self-referential parent_version_id FK. When a
  # periodization is destroyed, has_many :versions, dependent: :destroy walks
  # the version rows in load order — if a parent gets deleted before its child,
  # the child still references the parent and Postgres rejects the delete.
  # Deferring the check to COMMIT lets the whole subtree disappear together.
  FK_NAME = "fk_rails_periodization_versions_parent_version_id"

  def up
    remove_foreign_key :periodization_versions, column: :parent_version_id
    execute <<~SQL
      ALTER TABLE periodization_versions
      ADD CONSTRAINT #{FK_NAME}
      FOREIGN KEY (parent_version_id) REFERENCES periodization_versions (id)
      DEFERRABLE INITIALLY DEFERRED
    SQL
  end

  def down
    execute "ALTER TABLE periodization_versions DROP CONSTRAINT #{FK_NAME}"
    add_foreign_key :periodization_versions, :periodization_versions, column: :parent_version_id
  end
end
