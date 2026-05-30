class ChangeSessionsAuthenticatableIdToString < ActiveRecord::Migration[8.2]
  # The polymorphic Session can point at two principal types with different
  # primary-key types: User (bigint) and StudentIdentity (uuid). A single
  # bigint authenticatable_id column cannot store a uuid, so widen it to a
  # string that holds either serialization.
  def up
    remove_index :sessions, column: [ :authenticatable_type, :authenticatable_id ]
    execute "ALTER TABLE sessions ALTER COLUMN authenticatable_id TYPE varchar USING authenticatable_id::varchar"
    add_index :sessions, [ :authenticatable_type, :authenticatable_id ]
  end

  def down
    remove_index :sessions, column: [ :authenticatable_type, :authenticatable_id ]
    execute "DELETE FROM sessions WHERE authenticatable_type <> 'User'"
    execute "ALTER TABLE sessions ALTER COLUMN authenticatable_id TYPE bigint USING authenticatable_id::bigint"
    add_index :sessions, [ :authenticatable_type, :authenticatable_id ]
  end
end
