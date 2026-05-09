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

ActiveRecord::Schema[8.2].define(version: 2026_05_09_230000) do
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
    t.integer "age"
    t.text "anamnesis_md", default: "", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes_md", default: "", null: false
    t.uuid "organization_id", null: false
    t.string "primary_goal"
    t.text "restrictions_summary"
    t.string "sex"
    t.datetime "updated_at", null: false
    t.integer "weekly_frequency"
    t.index ["archived_at"], name: "index_students_on_archived_at"
    t.index ["organization_id"], name: "index_students_on_organization_id"
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
    t.text "error_message"
    t.string "kind", null: false
    t.uuid "organization_id", null: false
    t.text "proposed_anamnesis_md"
    t.string "status", null: false
    t.uuid "student_id", null: false
    t.uuid "target_workout_id"
    t.bigint "trainer_id", null: false
    t.text "transcript", default: "", null: false
    t.datetime "transcript_edited_at"
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_voice_recordings_on_organization_id"
    t.index ["status", "created_at"], name: "index_voice_recordings_on_status_and_created_at"
    t.index ["student_id", "created_at"], name: "index_voice_recordings_on_student_id_and_created_at"
    t.index ["student_id"], name: "index_voice_recordings_on_student_id"
    t.index ["target_workout_id"], name: "index_voice_recordings_on_target_workout_id"
    t.index ["trainer_id"], name: "index_voice_recordings_on_trainer_id"
  end

  create_table "workouts", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.text "content_md", default: "", null: false
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
  add_foreign_key "periodization_versions", "periodization_versions", column: "parent_version_id"
  add_foreign_key "periodization_versions", "periodizations"
  add_foreign_key "periodization_versions", "users", column: "trainer_id"
  add_foreign_key "periodization_versions", "voice_recordings"
  add_foreign_key "periodizations", "periodization_versions", column: "current_version_id"
  add_foreign_key "periodizations", "students"
  add_foreign_key "sessions", "users"
  add_foreign_key "students", "organizations"
  add_foreign_key "students", "periodizations", column: "active_periodization_id"
  add_foreign_key "users", "organizations"
  add_foreign_key "voice_recordings", "organizations"
  add_foreign_key "voice_recordings", "students"
  add_foreign_key "voice_recordings", "users", column: "trainer_id"
  add_foreign_key "voice_recordings", "workouts", column: "target_workout_id"
  add_foreign_key "workouts", "periodization_versions"
end
