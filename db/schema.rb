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

ActiveRecord::Schema[8.0].define(version: 2026_01_28_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "action_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "lead_id", null: false
    t.uuid "agent_run_id"
    t.string "action_type", null: false
    t.string "status", default: "ok", null: false
    t.jsonb "payload", default: {}, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_run_id"], name: "index_action_logs_on_agent_run_id"
    t.index ["created_at"], name: "index_action_logs_on_created_at"
    t.index ["lead_id"], name: "index_action_logs_on_lead_id"
  end

  create_table "admin_users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "agent_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "lead_id", null: false
    t.string "status", default: "started", null: false
    t.string "model"
    t.jsonb "input_context", default: {}, null: false
    t.jsonb "output_plan", default: {}, null: false
    t.jsonb "validation_errors"
    t.integer "duration_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lead_id"], name: "index_agent_runs_on_lead_id"
    t.index ["status"], name: "index_agent_runs_on_status"
  end

  create_table "assignments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "job_id", null: false
    t.uuid "subcontractor_id", null: false
    t.string "status", default: "assigned", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_assignments_on_job_id"
    t.index ["subcontractor_id"], name: "index_assignments_on_subcontractor_id"
  end

  create_table "jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "lead_id", null: false
    t.uuid "quote_id", null: false
    t.date "scheduled_date", null: false
    t.time "scheduled_window_start", null: false
    t.time "scheduled_window_end", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lead_id"], name: "index_jobs_on_lead_id"
    t.index ["quote_id"], name: "index_jobs_on_quote_id"
    t.index ["status"], name: "index_jobs_on_status"
  end

  create_table "leads", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "full_name", null: false
    t.string "email"
    t.string "phone"
    t.string "address_line1", null: false
    t.string "address_line2"
    t.string "city", null: false
    t.string "state", null: false
    t.string "postal_code", null: false
    t.string "service_requested", null: false
    t.text "notes"
    t.string "urgency_hint"
    t.string "status", default: "new", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_leads_on_status"
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "lead_id", null: false
    t.uuid "job_id"
    t.string "channel", default: "email", null: false
    t.string "to", null: false
    t.string "subject"
    t.text "body", null: false
    t.string "status", default: "stubbed", null: false
    t.string "provider_message_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_notifications_on_job_id"
    t.index ["lead_id"], name: "index_notifications_on_lead_id"
  end

  create_table "pricing_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "service_code", null: false
    t.integer "min_price_cents", null: false
    t.integer "max_price_cents", null: false
    t.integer "base_price_cents", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_code"], name: "index_pricing_rules_on_service_code"
  end

  create_table "quote_line_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "quote_id", null: false
    t.string "description", null: false
    t.integer "quantity", default: 1, null: false
    t.integer "unit_price_cents", null: false
    t.integer "total_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quote_id"], name: "index_quote_line_items_on_quote_id"
  end

  create_table "quotes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "lead_id", null: false
    t.uuid "agent_run_id", null: false
    t.integer "subtotal_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.decimal "confidence", precision: 3, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_run_id"], name: "index_quotes_on_agent_run_id"
    t.index ["lead_id"], name: "index_quotes_on_lead_id"
  end

  create_table "services", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_services_on_code", unique: true
  end

  create_table "subcontractor_availabilities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "subcontractor_id", null: false
    t.integer "day_of_week", null: false
    t.time "window_start", null: false
    t.time "window_end", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subcontractor_id", "day_of_week"], name: "index_subcontractor_availabilities_on_sub_day"
    t.index ["subcontractor_id"], name: "index_subcontractor_availabilities_on_subcontractor_id"
  end

  create_table "subcontractors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "phone", null: false
    t.string "email"
    t.jsonb "service_codes", default: [], null: false
    t.jsonb "base_location", default: {}, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "action_logs", "agent_runs"
  add_foreign_key "action_logs", "leads"
  add_foreign_key "agent_runs", "leads"
  add_foreign_key "assignments", "jobs"
  add_foreign_key "assignments", "subcontractors"
  add_foreign_key "jobs", "leads"
  add_foreign_key "jobs", "quotes"
  add_foreign_key "notifications", "jobs"
  add_foreign_key "notifications", "leads"
  add_foreign_key "quote_line_items", "quotes"
  add_foreign_key "quotes", "agent_runs"
  add_foreign_key "quotes", "leads"
  add_foreign_key "subcontractor_availabilities", "subcontractors"
end
