class CreateHarborSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_sessions do |t|
      t.uuid :user_id, null: false
      t.string :step, null: false, default: "chat"
      t.string :status, null: false, default: "in_progress"
      t.string :stress_mode, null: false, default: "neutral"
      t.boolean :calm_mode_opt_in, null: false, default: false
      t.jsonb :assessment, null: false, default: {}
      t.timestamps
    end
    add_index :onboarding_sessions, :user_id, unique: true

    create_table :document_details do |t|
      t.references :onboarding_session, null: false, foreign_key: true, index: { unique: true }
      t.string :full_name
      t.date :date_of_birth
      t.text :address
      t.jsonb :field_sources, null: false, default: {}
      t.datetime :confirmed_at
      t.timestamps
    end

    create_table :consent_events do |t|
      t.references :onboarding_session, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :policy_version, null: false, default: "2026-08-20"
      t.timestamps
    end

    create_table :appointment_slots do |t|
      t.datetime :starts_at, null: false
      t.string :channel, null: false, default: "video_or_phone"
      t.timestamps
    end
    add_index :appointment_slots, :starts_at, unique: true

    create_table :bookings do |t|
      t.references :onboarding_session, null: false, foreign_key: true, index: { unique: true }
      t.references :appointment_slot, null: false, foreign_key: true, index: { unique: true }
      t.string :reference, null: false
      t.timestamps
    end
    add_index :bookings, :reference, unique: true

    create_table :analytics_events do |t|
      t.uuid :anonymous_session_id, null: false
      t.string :event_name, null: false
      t.string :step
      t.integer :duration_ms
      t.jsonb :properties, null: false, default: {}
      t.timestamps
    end
    add_index :analytics_events, %i[event_name created_at]

    create_table :deletion_audits do |t|
      t.string :subject_digest, null: false
      t.string :scope, null: false, default: "all_onboarding_data"
      t.timestamps
    end
    add_index :deletion_audits, :subject_digest
  end
end
