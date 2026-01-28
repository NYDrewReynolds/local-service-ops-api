class EnablePgcryptoAndCreateMvpTables < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :admin_users, id: :uuid do |t|
      t.string :email, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :admin_users, :email, unique: true

    create_table :leads, id: :uuid do |t|
      t.string :full_name, null: false
      t.string :email
      t.string :phone
      t.string :address_line1, null: false
      t.string :address_line2
      t.string :city, null: false
      t.string :state, null: false
      t.string :postal_code, null: false
      t.string :service_requested, null: false
      t.text :notes
      t.string :urgency_hint
      t.string :status, null: false, default: "new"

      t.timestamps
    end
    add_index :leads, :status

    create_table :services, id: :uuid do |t|
      t.string :name, null: false
      t.string :code, null: false

      t.timestamps
    end
    add_index :services, :code, unique: true

    create_table :subcontractors, id: :uuid do |t|
      t.string :name, null: false
      t.string :phone, null: false
      t.string :email
      t.jsonb :service_codes, null: false, default: []
      t.jsonb :base_location, null: false, default: {}
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    create_table :subcontractor_availabilities, id: :uuid do |t|
      t.references :subcontractor, null: false, type: :uuid, foreign_key: true
      t.integer :day_of_week, null: false
      t.time :window_start, null: false
      t.time :window_end, null: false

      t.timestamps
    end
    add_index :subcontractor_availabilities, %i[subcontractor_id day_of_week], name: "index_subcontractor_availabilities_on_sub_day"

    create_table :pricing_rules, id: :uuid do |t|
      t.string :service_code, null: false
      t.integer :min_price_cents, null: false
      t.integer :max_price_cents, null: false
      t.integer :base_price_cents, null: false
      t.text :notes

      t.timestamps
    end
    add_index :pricing_rules, :service_code

    create_table :agent_runs, id: :uuid do |t|
      t.references :lead, null: false, type: :uuid, foreign_key: true
      t.string :status, null: false, default: "started"
      t.string :model
      t.jsonb :input_context, null: false, default: {}
      t.jsonb :output_plan, null: false, default: {}
      t.jsonb :validation_errors
      t.integer :duration_ms

      t.timestamps
    end
    add_index :agent_runs, :status

    create_table :quotes, id: :uuid do |t|
      t.references :lead, null: false, type: :uuid, foreign_key: true
      t.references :agent_run, null: false, type: :uuid, foreign_key: true
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.decimal :confidence, precision: 3, scale: 2, null: false, default: 0.0

      t.timestamps
    end

    create_table :quote_line_items, id: :uuid do |t|
      t.references :quote, null: false, type: :uuid, foreign_key: true
      t.string :description, null: false
      t.integer :quantity, null: false, default: 1
      t.integer :unit_price_cents, null: false
      t.integer :total_cents, null: false

      t.timestamps
    end

    create_table :jobs, id: :uuid do |t|
      t.references :lead, null: false, type: :uuid, foreign_key: true
      t.references :quote, null: false, type: :uuid, foreign_key: true
      t.date :scheduled_date, null: false
      t.time :scheduled_window_start, null: false
      t.time :scheduled_window_end, null: false
      t.string :status, null: false, default: "scheduled"

      t.timestamps
    end
    add_index :jobs, :status

    create_table :assignments, id: :uuid do |t|
      t.references :job, null: false, type: :uuid, foreign_key: true
      t.references :subcontractor, null: false, type: :uuid, foreign_key: true
      t.string :status, null: false, default: "assigned"

      t.timestamps
    end

    create_table :notifications, id: :uuid do |t|
      t.references :lead, null: false, type: :uuid, foreign_key: true
      t.references :job, type: :uuid, foreign_key: true
      t.string :channel, null: false, default: "email"
      t.string :to, null: false
      t.string :subject
      t.text :body, null: false
      t.string :status, null: false, default: "stubbed"
      t.string :provider_message_id

      t.timestamps
    end

    create_table :action_logs, id: :uuid do |t|
      t.references :lead, null: false, type: :uuid, foreign_key: true
      t.references :agent_run, type: :uuid, foreign_key: true
      t.string :action_type, null: false
      t.string :status, null: false, default: "ok"
      t.jsonb :payload, null: false, default: {}
      t.text :error_message

      t.timestamps
    end
    add_index :action_logs, :created_at
  end
end
