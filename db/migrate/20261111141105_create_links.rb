# Other people's sites, listed on the blogroll page
class CreateLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :links do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.string :feed_url
      t.text :description

      t.timestamps
    end
    add_index :links, :url, unique: true
  end
end
