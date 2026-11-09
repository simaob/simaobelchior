class AddHostToPageViews < ActiveRecord::Migration[8.1]
  # Page views recorded before this were all on this site, so they get its host
  def change
    add_column :page_views, :host, :string, null: false, default: "simaobelchior.com"
    change_column_default :page_views, :host, from: "simaobelchior.com", to: nil
  end
end
