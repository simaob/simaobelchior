class Tag < ApplicationRecord
  has_many :article_tags, dependent: :destroy
  has_many :articles, through: :article_tags

  validates :name, presence: true, uniqueness: true

  normalizes :name, with: ->(name) { name.strip.downcase }

  # Tags in use, most used first, each with the number of articles in articles_count
  scope :by_usage, -> {
    joins(:article_tags)
      .group(:id)
      .select("tags.*, COUNT(article_tags.id) AS articles_count")
      .order("articles_count DESC", :name)
  }

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

  # Pairs of tags in use that look like the same tag written two ways, the less used one first
  def self.lookalikes
    by_usage.to_a.combination(2).select { |more, less| similar?(more.name, less.name) }.map(&:reverse)
  end

  # Spelt differently, or with a typo or two. The same test as the article form's tags field
  # in tag_input_controller.js, so keep the two in step.
  def self.similar?(a, b)
    x, y = squash(a), squash(b)
    return true if x == y
    return false if [ x.length, y.length ].min < 3

    distance(x, y) <= ([ x.length, y.length ].max >= 8 ? 2 : 1)
  end

  # Letters and digits only, without a plural "s", so "action text", "action-text" and
  # "actiontext" all come out the same
  def self.squash(name)
    letters = name.downcase.gsub(/[^\p{L}\p{N}]/, "")
    letters.length > 3 ? letters.delete_suffix("s") : letters
  end

  # Edits to turn one into the other, where swapping two neighbouring letters is one edit
  def self.distance(a, b)
    d = Array.new(a.length + 1) { |i| [ i ] + [ 0 ] * b.length }
    (1..b.length).each { |j| d[0][j] = j }

    (1..a.length).each do |i|
      (1..b.length).each do |j|
        cost = a[i - 1] == b[j - 1] ? 0 : 1
        d[i][j] = [ d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost ].min
        if i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]
          d[i][j] = [ d[i][j], d[i - 2][j - 2] + 1 ].min
        end
      end
    end
    d[a.length][b.length]
  end
  private_class_method :squash, :distance

  # Moves this tag's articles to another tag, then deletes this one
  def merge_into(other)
    raise ArgumentError, "can't merge #{name} into itself" if other == self

    transaction do
      article_tags.where.not(article_id: other.article_tags.select(:article_id)).update_all(tag_id: other.id)
      destroy! # with the links to articles that already had the other tag
    end
  end
end
