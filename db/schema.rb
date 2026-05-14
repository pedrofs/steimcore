# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.2].define(version: 2026_05_14_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agent_chats", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "chattable_id", null: false
    t.string "chattable_type", null: false
    t.datetime "created_at", null: false
    t.uuid "model_id"
    t.uuid "organization_id", null: false
    t.string "state", default: "idle", null: false
    t.datetime "updated_at", null: false
    t.index ["chattable_type", "chattable_id"], name: "index_agent_chats_on_chattable_type_and_chattable_id", unique: true
    t.index ["model_id"], name: "index_agent_chats_on_model_id"
    t.index ["organization_id"], name: "index_agent_chats_on_organization_id"
  end

  create_table "agent_messages", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.integer "cache_creation_tokens"
    t.integer "cached_tokens"
    t.uuid "chat_id", null: false
    t.text "content"
    t.jsonb "content_raw"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.uuid "model_id"
    t.integer "output_tokens"
    t.string "role", null: false
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.uuid "tool_call_id"
    t.bigint "trainer_id"
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_agent_messages_on_chat_id"
    t.index ["model_id"], name: "index_agent_messages_on_model_id"
    t.index ["role"], name: "index_agent_messages_on_role"
    t.index ["tool_call_id"], name: "index_agent_messages_on_tool_call_id"
    t.index ["trainer_id"], name: "index_agent_messages_on_trainer_id"
  end

  create_table "agent_models", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.jsonb "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.jsonb "metadata", default: {}
    t.jsonb "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.jsonb "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_agent_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_agent_models_on_family"
    t.index ["modalities"], name: "index_agent_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_agent_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_agent_models_on_provider"
  end

  create_table "agent_tool_calls", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.uuid "message_id", null: false
    t.string "name", null: false
    t.jsonb "result"
    t.text "thought_signature"
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_agent_tool_calls_on_message_id"
    t.index ["name"], name: "index_agent_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_agent_tool_calls_on_tool_call_id", unique: true
  end

  create_table "invitations", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.bigint "invited_by_id", null: false
    t.uuid "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["organization_id", "email_address"], name: "idx_one_pending_invitation_per_email_per_org", unique: true, where: "(accepted_at IS NULL)"
    t.index ["organization_id"], name: "index_invitations_on_organization_id"
  end

  create_table "organizations", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "equipment_list_md", default: "", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "periodization_versions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.text "body_md", default: "", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.uuid "parent_version_id"
    t.uuid "periodization_id", null: false
    t.string "status", null: false
    t.bigint "trainer_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "voice_recording_id"
    t.index ["parent_version_id"], name: "index_periodization_versions_on_parent_version_id"
    t.index ["periodization_id", "created_at"], name: "idx_on_periodization_id_created_at_2ccdf56ebe"
    t.index ["periodization_id"], name: "index_periodization_versions_on_periodization_id"
    t.index ["trainer_id"], name: "index_periodization_versions_on_trainer_id"
    t.index ["voice_recording_id"], name: "index_periodization_versions_on_voice_recording_id"
  end

  create_table "periodizations", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.uuid "current_version_id"
    t.uuid "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id", "archived_at"], name: "index_periodizations_on_student_id_and_archived_at"
    t.index ["student_id"], name: "index_periodizations_on_student_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "students", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "active_periodization_id"
    t.text "anamnesis_md", default: "", null: false
    t.datetime "archived_at"
    t.date "birthday"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.text "notes_md", default: "", null: false
    t.uuid "organization_id", null: false
    t.string "phone"
    t.string "primary_goal"
    t.text "restrictions_summary"
    t.string "sex"
    t.datetime "updated_at", null: false
    t.integer "weekly_frequency"
    t.index ["archived_at"], name: "index_students_on_archived_at"
    t.index ["email"], name: "index_students_on_email", where: "(email IS NOT NULL)"
    t.index ["organization_id"], name: "index_students_on_organization_id"
    t.index ["phone"], name: "index_students_on_phone", where: "(phone IS NOT NULL)"
  end

  create_table "training_sessions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.jsonb "blocks_snapshot", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.uuid "periodization_version_id"
    t.jsonb "progress", default: [], null: false
    t.uuid "student_id", null: false
    t.bigint "trainer_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "workout_id"
    t.string "workout_name_snapshot", null: false
    t.integer "workout_position_snapshot", null: false
    t.index ["periodization_version_id"], name: "index_training_sessions_on_periodization_version_id"
    t.index ["student_id", "finished_at"], name: "index_training_sessions_on_student_id_and_finished_at"
    t.index ["student_id"], name: "idx_one_active_training_session_per_student", unique: true, where: "(finished_at IS NULL)"
    t.index ["trainer_id", "finished_at"], name: "index_training_sessions_on_trainer_id_and_finished_at"
    t.index ["workout_id"], name: "index_training_sessions_on_workout_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.uuid "organization_id", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  create_table "voice_recordings", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "dismissed_at"
    t.text "error_message"
    t.string "kind", null: false
    t.uuid "organization_id", null: false
    t.text "proposed_anamnesis_md"
    t.string "status", null: false
    t.uuid "student_id", null: false
    t.uuid "target_periodization_version_id"
    t.uuid "target_workout_id"
    t.bigint "trainer_id", null: false
    t.text "transcript", default: "", null: false
    t.datetime "transcript_edited_at"
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_voice_recordings_on_organization_id"
    t.index ["status", "created_at"], name: "index_voice_recordings_on_status_and_created_at"
    t.index ["student_id", "created_at"], name: "index_voice_recordings_on_student_id_and_created_at"
    t.index ["student_id"], name: "index_voice_recordings_on_student_id"
    t.index ["target_periodization_version_id"], name: "index_voice_recordings_on_target_periodization_version_id"
    t.index ["target_workout_id"], name: "index_voice_recordings_on_target_workout_id"
    t.index ["trainer_id"], name: "index_voice_recordings_on_trainer_id"
  end

  create_table "workouts", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.jsonb "blocks", default: [], null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "periodization_version_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["periodization_version_id", "position"], name: "index_workouts_on_periodization_version_id_and_position"
    t.index ["periodization_version_id"], name: "index_workouts_on_periodization_version_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_chats", "agent_models", column: "model_id"
  add_foreign_key "agent_chats", "organizations"
  add_foreign_key "agent_messages", "agent_chats", column: "chat_id"
  add_foreign_key "agent_messages", "agent_models", column: "model_id"
  add_foreign_key "agent_messages", "agent_tool_calls", column: "tool_call_id"
  add_foreign_key "agent_messages", "users", column: "trainer_id"
  add_foreign_key "agent_tool_calls", "agent_messages", column: "message_id"
  add_foreign_key "invitations", "organizations"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "periodization_versions", "periodization_versions", column: "parent_version_id", name: "fk_rails_periodization_versions_parent_version_id", deferrable: :deferred
  add_foreign_key "periodization_versions", "periodizations"
  add_foreign_key "periodization_versions", "users", column: "trainer_id"
  add_foreign_key "periodization_versions", "voice_recordings", name: "fk_rails_periodization_versions_voice_recording_id", deferrable: :deferred
  add_foreign_key "periodizations", "periodization_versions", column: "current_version_id", name: "fk_rails_periodizations_current_version_id", deferrable: :deferred
  add_foreign_key "periodizations", "students"
  add_foreign_key "sessions", "users"
  add_foreign_key "students", "organizations"
  add_foreign_key "students", "periodizations", column: "active_periodization_id", name: "fk_rails_students_active_periodization_id", deferrable: :deferred
  add_foreign_key "training_sessions", "periodization_versions", on_delete: :nullify
  add_foreign_key "training_sessions", "students"
  add_foreign_key "training_sessions", "users", column: "trainer_id"
  add_foreign_key "training_sessions", "workouts", on_delete: :nullify
  add_foreign_key "users", "organizations"
  add_foreign_key "voice_recordings", "organizations"
  add_foreign_key "voice_recordings", "periodization_versions", column: "target_periodization_version_id"
  add_foreign_key "voice_recordings", "students"
  add_foreign_key "voice_recordings", "users", column: "trainer_id"
  add_foreign_key "voice_recordings", "workouts", column: "target_workout_id"
  add_foreign_key "workouts", "periodization_versions"
end
