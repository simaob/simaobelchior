class AddSearchTextToArticles < ActiveRecord::Migration[8.1]
  def up
    add_column :articles, :search_text, :text

    Article.reset_column_information
    Article.includes(:rich_text_body).find_each do |article|
      article.update_column(:search_text, article.searchable_text)
    end
  end

  def down
    remove_column :articles, :search_text
  end
end
