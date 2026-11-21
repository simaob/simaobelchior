namespace :tags do
  desc "List tags that look like the same tag written two ways"
  task lookalikes: :environment do
    pairs = Tag.lookalikes
    # Single quotes, so a copied command keeps tag names as they are, $ and backticks included
    quote = ->(text) { "'#{text.gsub("'") { %q('\'') }}'" }

    if pairs.empty?
      puts "No lookalike tags."
    else
      pairs.each do |less, more|
        puts "#{less.name} (#{less.articles_count}) looks like #{more.name} (#{more.articles_count})"
        puts "  bin/rails #{quote.call("tags:merge[#{less.name},#{more.name}]")}"
      end
    end
  end

  desc "Move a tag's articles to another tag, then delete it"
  task :merge, [ :from, :into ] => :environment do |_task, args|
    from = Tag.find_by(name: args[:from].to_s)
    into = Tag.find_by(name: args[:into].to_s)
    abort "No tag called #{args[:from].inspect}" unless from
    abort "No tag called #{args[:into].inspect}" unless into

    begin
      from.merge_into(into)
    rescue ArgumentError => error
      abort error.message
    end
    puts "Merged #{from.name} into #{into.name}. #{into.articles.count} articles now have #{into.name}."
  end
end
