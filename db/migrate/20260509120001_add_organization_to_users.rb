class AddOrganizationToUsers < ActiveRecord::Migration[8.2]
  def up
    add_reference :users, :organization, type: :uuid, foreign_key: true

    if User.where(organization_id: nil).any?
      org_id = ActiveRecord::Base.connection.select_value(
        "INSERT INTO organizations (id, name, equipment_list_md, created_at, updated_at)
         VALUES (uuidv7(), 'SteimFit', '', NOW(), NOW())
         ON CONFLICT DO NOTHING
         RETURNING id"
      ) || ActiveRecord::Base.connection.select_value(
        "SELECT id FROM organizations WHERE name = 'SteimFit' LIMIT 1"
      )
      execute "UPDATE users SET organization_id = '#{org_id}' WHERE organization_id IS NULL"
    end

    change_column_null :users, :organization_id, false
  end

  def down
    remove_reference :users, :organization, foreign_key: true
  end
end
