class CreateAgentTables < ActiveRecord::Migration[8.2]
  def change
    create_table :agent_models, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :model_id, null: false
      t.string :name, null: false
      t.string :provider, null: false
      t.string :family
      t.datetime :model_created_at
      t.integer :context_window
      t.integer :max_output_tokens
      t.date :knowledge_cutoff
      t.jsonb :modalities, default: {}
      t.jsonb :capabilities, default: []
      t.jsonb :pricing, default: {}
      t.jsonb :metadata, default: {}
      t.timestamps

      t.index [ :provider, :model_id ], unique: true
      t.index :provider
      t.index :family
      t.index :capabilities, using: :gin
      t.index :modalities, using: :gin
    end

    create_table :agent_chats, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :model, type: :uuid, foreign_key: { to_table: :agent_models }
      t.string :chattable_type, null: false
      t.uuid :chattable_id, null: false
      t.string :state, null: false, default: "idle"
      t.timestamps

      t.index [ :chattable_type, :chattable_id ], unique: true
    end

    create_table :agent_tool_calls, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :tool_call_id, null: false
      t.string :name, null: false
      t.text :thought_signature
      t.jsonb :arguments, default: {}
      t.jsonb :result
      t.timestamps

      t.index :tool_call_id, unique: true
      t.index :name
    end

    create_table :agent_messages, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :chat, type: :uuid, null: false, foreign_key: { to_table: :agent_chats }
      t.references :trainer, foreign_key: { to_table: :users }
      t.references :tool_call, type: :uuid, foreign_key: { to_table: :agent_tool_calls }
      t.references :model, type: :uuid, foreign_key: { to_table: :agent_models }
      t.string :role, null: false
      t.text :content
      t.jsonb :content_raw
      t.text :thinking_text
      t.text :thinking_signature
      t.integer :thinking_tokens
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :cached_tokens
      t.integer :cache_creation_tokens
      t.timestamps

      t.index :role
    end

    # tool_calls reference their parent message; add the FK after agent_messages exists.
    add_reference :agent_tool_calls, :message,
                  type: :uuid, null: false,
                  foreign_key: { to_table: :agent_messages }
  end
end
