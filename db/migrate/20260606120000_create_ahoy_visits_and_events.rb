class CreateAhoyVisitsAndEvents < ActiveRecord::Migration[8.2]
  def change
    create_table :ahoy_visits, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :visit_token
      t.string :visitor_token

      # Student-only product analytics: the visitor behind a visit is always a
      # StudentIdentity (uuid), so this is a single-target association — not the
      # polymorphic User|StudentIdentity principal pattern. ahoy writes user_id
      # directly at visit creation from Ahoy.user_method.
      t.references :user, type: :uuid, null: true, index: true

      # request context
      t.string :ip
      t.text   :user_agent
      t.text   :referrer
      t.string :referring_domain
      t.text   :landing_page

      # technology (parsed from user_agent)
      t.string :browser
      t.string :os
      t.string :device_type

      # utm parameters
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_term
      t.string :utm_content
      t.string :utm_campaign

      t.timestamp :started_at
    end

    create_table :ahoy_events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :visit, type: :uuid, null: true,
                   foreign_key: { to_table: :ahoy_visits, on_delete: :cascade }, index: true
      t.string :name
      t.jsonb  :properties
      t.timestamp :time
    end

    add_index :ahoy_visits, :visit_token, unique: true
    add_index :ahoy_visits, :started_at
    add_index :ahoy_events, [ :name, :time ]
    # Containment lookups (e.g. properties @> '{"organization_id":"…"}') back the
    # per-organization usage dashboard. jsonb_path_ops keeps the index compact.
    add_index :ahoy_events, :properties, using: :gin, opclass: :jsonb_path_ops
  end
end
