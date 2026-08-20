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

ActiveRecord::Schema[8.1].define(version: 2026_08_20_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admin_access_audits", force: :cascade do |t|
    t.string "action", null: false
    t.string "actor_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action", "created_at"], name: "index_admin_access_audits_on_action_and_created_at"
    t.index ["actor_digest"], name: "index_admin_access_audits_on_actor_digest"
  end

  create_table "analytics_events", force: :cascade do |t|
    t.uuid "anonymous_session_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "event_name", null: false
    t.jsonb "properties", default: {}, null: false
    t.string "step"
    t.datetime "updated_at", null: false
    t.index ["event_name", "created_at"], name: "index_analytics_events_on_event_name_and_created_at"
  end

  create_table "appointment_slots", force: :cascade do |t|
    t.string "channel", default: "video_or_phone", null: false
    t.datetime "created_at", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["starts_at"], name: "index_appointment_slots_on_starts_at", unique: true
  end

  create_table "bookings", force: :cascade do |t|
    t.bigint "appointment_slot_id", null: false
    t.datetime "created_at", null: false
    t.bigint "onboarding_session_id", null: false
    t.string "reference", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_slot_id"], name: "index_bookings_on_appointment_slot_id", unique: true
    t.index ["onboarding_session_id"], name: "index_bookings_on_onboarding_session_id", unique: true
    t.index ["reference"], name: "index_bookings_on_reference", unique: true
  end

  create_table "consent_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.bigint "onboarding_session_id", null: false
    t.string "policy_version", default: "2026-08-20", null: false
    t.datetime "updated_at", null: false
    t.index ["onboarding_session_id"], name: "index_consent_events_on_onboarding_session_id"
  end

  create_table "deletion_audits", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "scope", default: "all_onboarding_data", null: false
    t.string "subject_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["subject_digest"], name: "index_deletion_audits_on_subject_digest"
  end

  create_table "document_details", force: :cascade do |t|
    t.text "address"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.jsonb "field_sources", default: {}, null: false
    t.string "full_name"
    t.bigint "onboarding_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["onboarding_session_id"], name: "index_document_details_on_onboarding_session_id", unique: true
  end

  create_table "onboarding_sessions", force: :cascade do |t|
    t.jsonb "assessment", default: {}, null: false
    t.boolean "calm_mode_opt_in", default: false, null: false
    t.datetime "created_at", null: false
    t.string "status", default: "in_progress", null: false
    t.string "step", default: "chat", null: false
    t.string "stress_mode", default: "neutral", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_onboarding_sessions_on_user_id", unique: true
  end

  add_foreign_key "bookings", "appointment_slots"
  add_foreign_key "bookings", "onboarding_sessions"
  add_foreign_key "consent_events", "onboarding_sessions"
  add_foreign_key "document_details", "onboarding_sessions"
end
