class CreatePolls < ActiveRecord::Migration
  def change
    create_table :polls do |t|
      t.integer :constituency_id
      t.integer :party_id
      t.integer :votes

      t.timestamps null: false
    end
  end
end
