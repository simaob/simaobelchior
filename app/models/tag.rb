class Tag < ApplicationRecord
  has_many :article_tags, dependent: :destroy
  has_many :articles, through: :article_tags

  validates :name, presence: true, uniqueness: true

  normalizes :name, with: ->(name) { name.strip.downcase }

  # Find or create tags from comma-separated string
  def self.from_list(tag_string)
    return [] if tag_string.blank?

    tag_names = tag_string.split(",").map do |name|
      name.strip.downcase
    end.reject(&:blank?).uniq

    tag_names.map do |name|
      find_or_create_by(name: name)
    end
  end
end
