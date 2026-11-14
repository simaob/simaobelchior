# Visits per article are counted over all time by path, which the day index doesn't help with
class AddPathIndexToPageViews < ActiveRecord::Migration[8.1]
  def change
    add_index :page_views, :path
  end
end
