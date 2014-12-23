class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :provider
      t.string :uid
      t.string :name
      t.string :image
      t.string :token
      t.datetime :expires_at

      t.integer :preferred_party_id
      t.integer :willing_party_id
      
      t.timestamps null: false
    end
  end
end
