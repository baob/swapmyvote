class AddConsentShareEmailToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :consent_share_email, :boolean, default: false, null: false
  end
end
