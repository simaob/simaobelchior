# A site on the blogroll: someone else's blog or site worth following
class Link < ApplicationRecord
  WEB_SCHEMES = %w[http https].freeze

  normalizes :name, :description, with: ->(value) { value.strip.presence }
  # Pasting "example.com" should work, so add the scheme when it's missing
  normalizes :url, :feed_url, with: ->(value) {
    value = value.strip
    value.blank? || value.match?(%r{\A[a-z][a-z0-9+.-]*://}i) ? value.presence : "https://#{value}"
  }

  validates :name, presence: true
  validates :url, presence: true, uniqueness: { case_sensitive: false }
  validate :urls_are_web_addresses

  scope :alphabetical, -> { order(Arel.sql("name COLLATE NOCASE"), :id) }
  scope :with_feed, -> { where.not(feed_url: nil) }

  # The address without the scheme or "www.", as shown under the name
  def domain
    URI.parse(url).host.delete_prefix("www.")
  rescue URI::InvalidURIError
    url
  end

  private

  def urls_are_web_addresses
    { url: url, feed_url: feed_url }.each do |attribute, value|
      next if value.blank?
      errors.add(attribute, "must be a web address starting with http:// or https://") unless web_address?(value)
    end
  end

  def web_address?(value)
    uri = URI.parse(value)
    WEB_SCHEMES.include?(uri.scheme&.downcase) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end
end
