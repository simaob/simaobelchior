class CreateFeedFetches < ActiveRecord::Migration[8.1]
  def change
    create_table :feed_fetches do |t|
      t.date :fetched_on, null: false
      t.string :fetcher_hash, null: false
      t.string :reader, null: false
      t.integer :subscribers
      t.integer :fetches, null: false, default: 1
      t.timestamps
    end
    add_index :feed_fetches, [ :fetched_on, :fetcher_hash ], unique: true
  end
end
