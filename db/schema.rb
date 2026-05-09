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

ActiveRecord::Schema[8.2].define(version: 2026_05_09_120002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "organizations", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "equipment_list_md", default: "", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
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

  add_foreign_key "sessions", "users"
  add_foreign_key "students", "organizations"
  add_foreign_key "users", "organizations"
end
