class CreateAdminAccessAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_access_audits do |t|
      t.string :actor_digest, null: false
      t.string :action, null: false
      t.timestamps
    end

    add_index :admin_access_audits, :actor_digest
    add_index :admin_access_audits, %i[action created_at]
  end
end
