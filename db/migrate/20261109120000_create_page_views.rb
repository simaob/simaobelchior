class CreatePageViews < ActiveRecord::Migration[8.1]
  def change
    create_table :page_views do |t|
      t.string :path, null: false
      t.string :referrer_host
      t.string :visitor_hash, null: false
      t.date :visited_on, null: false
      t.datetime :created_at, null: false
    end
    add_index :page_views, [ :visited_on, :visitor_hash ]

    create_table :visitor_salts do |t|
      t.date :day, null: false, index: { unique: true }
      t.string :value, null: false
    end
  end
end
