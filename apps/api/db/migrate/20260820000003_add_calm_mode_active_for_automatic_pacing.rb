class AddCalmModeActiveForAutomaticPacing < ActiveRecord::Migration[8.1]
  def up
    add_column :onboarding_sessions, :calm_mode_active, :boolean, null: false, default: false
    execute <<~SQL.squish
      update onboarding_sessions
      set calm_mode_active = calm_mode_opt_in
      where calm_mode_opt_in = true
    SQL
  end

  def down
    remove_column :onboarding_sessions, :calm_mode_active
  end
end
