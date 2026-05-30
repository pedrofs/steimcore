class MakeSessionsAuthenticatablePolymorphic < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key :sessions, :users

    rename_column :sessions, :user_id, :authenticatable_id
    add_column :sessions, :authenticatable_type, :string
    execute "UPDATE sessions SET authenticatable_type = 'User'"
    change_column_null :sessions, :authenticatable_type, false

    remove_index :sessions, column: :authenticatable_id if index_exists?(:sessions, :authenticatable_id)
    add_index :sessions, [ :authenticatable_type, :authenticatable_id ]
  end

  def down
    remove_index :sessions, column: [ :authenticatable_type, :authenticatable_id ]

    execute "DELETE FROM sessions WHERE authenticatable_type <> 'User'"
    remove_column :sessions, :authenticatable_type
    rename_column :sessions, :authenticatable_id, :user_id

    add_index :sessions, :user_id
    add_foreign_key :sessions, :users
  end
end
