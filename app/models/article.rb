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
    slug_candidate = base_slug
    counter = 1

    while Article.exists?(slug: slug_candidate)
      slug_candidate = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = slug_candidate
  end
end
