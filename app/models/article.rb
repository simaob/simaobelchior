class Article < ApplicationRecord
  has_rich_text :body

  validates :title, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, if: -> { slug.blank? }

  scope :published, -> { where("published_at <= ?", Time.current).order(published_at: :desc) }
  scope :drafts, -> { where(published_at: nil).order(created_at: :desc) }
  scope :recent, -> { order(published_at: :desc) }

  def published?
    published_at.present? && published_at <= Time.current
  end

  def excerpt(length: 500)
    return "" unless body.present?
    body.to_plain_text.truncate(length, separator: " ")
  end

  private

  def generate_slug
    return if title.blank?
    base_slug = title.parameterize

    # Try the base slug first
    return self.slug = base_slug unless Article.where(slug: base_slug).exists?

    # If base slug exists, find all similar slugs in one query
    existing_slugs = Article.where("slug LIKE ?", "#{base_slug}%")
                           .where.not(id: id) # Exclude self when updating
                           .pluck(:slug)
                           .to_set

    # Find the next available number
    counter = 1
    loop do
      slug_candidate = "#{base_slug}-#{counter}"
      unless existing_slugs.include?(slug_candidate)
        self.slug = slug_candidate
        break
      end
      counter += 1
    end
  end
end
