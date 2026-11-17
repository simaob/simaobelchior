class CreateGameEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :game_events do |t|
      t.string :game, null: false
      t.string :level
      t.string :name, null: false
      t.json :data, null: false, default: {}
      t.string :visitor_hash, null: false
      t.date :occurred_on, null: false
      t.datetime :created_at, null: false
    end
    add_index :game_events, :occurred_on
  end
end
