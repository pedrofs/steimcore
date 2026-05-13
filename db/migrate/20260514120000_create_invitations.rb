class CreateInvitations < ActiveRecord::Migration[8.2]
  def change
    create_table :invitations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :email_address, null: false
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :invited_by, type: :bigint, null: false, foreign_key: { to_table: :users }
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :invitations, [ :organization_id, :email_address ],
              unique: true,
              where: "accepted_at IS NULL",
              name: "idx_one_pending_invitation_per_email_per_org"
  end
end
