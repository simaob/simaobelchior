class AddFeaturedToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :featured, :boolean, default: false, null: false
  end
end
