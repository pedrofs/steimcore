class CreatePushSubscriptions < ActiveRecord::Migration[8.2]
  def change
    create_table :push_subscriptions, id: :uuid, default: -> { "uuidv7()" } do |t|
      # Polymorphic owner — a User (trainer) or a StudentIdentity, mirroring the
      # `authenticatable` association on Session. The id column is a string
      # because the two principals have different PK types (User: bigint,
      # StudentIdentity: uuid), exactly as the sessions table stores it.
      t.references :authenticatable, type: :string, polymorphic: true, null: false

      # The browser push endpoint is globally unique; re-subscribing the same
      # browser returns the same endpoint, so it doubles as the upsert key.
      t.string :endpoint, null: false
      t.string :p256dh_key, null: false
      t.string :auth_key, null: false
      t.string :user_agent

      t.timestamps
    end

    add_index :push_subscriptions, :endpoint, unique: true
  end
end
