#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "net/http"
require "optparse"
require "rexml/document"
require "tempfile"
require "uri"
require "yaml"

require_relative "publication_tools"

module AutoUpdater
  ROOT = File.expand_path("..", __dir__)
  DEFAULT_CONFIG = File.join(ROOT, "_data", "auto_updater.yml")
  FEATURED_PATH = File.join(ROOT, "_data", "featured_publications.yml")
  SUPPORTED_SOURCE_KINDS = %w[
    arxiv
    bibtex
    dblp_bibtex
    semantic_scholar_bibtex
    google_scholar_manual
  ].freeze

  module_function

  def usage!
    warn <<~USAGE
      Usage:
        ruby scripts/auto_updater.rb audit [--config PATH]
        ruby scripts/auto_updater.rb plan [--config PATH]
        ruby scripts/auto_updater.rb sync-publications [--config PATH] [--apply]
        ruby scripts/auto_updater.rb import-arxiv ARXIV_ID --topics "Topic A,Topic B" [--apply]
        ruby scripts/auto_updater.rb import-bibtex PATH --topics "Topic A,Topic B" [--apply]
        ruby scripts/auto_updater.rb suggest-selected [--config PATH] [--apply]

      Notes:
        Dry-run is the default for all write-capable commands.
        Google Scholar is manual-export-only; do not scrape Scholar pages.
    USAGE
    exit 1
  end

  def relative(path)
    path.to_s.sub("#{ROOT}/", "")
  end

  def blank?(value)
    value.nil? || value.to_s.strip.empty?
  end

  def load_yaml(path, default)
    return default unless File.exist?(path)

    PublicationTools.stringify_keys(YAML.safe_load(
      File.read(path),
      permitted_classes: [Date, Time],
      aliases: true
    ) || default)
  rescue Psych::SyntaxError => e
    raise "Invalid YAML in #{relative(path)}: #{e.message}"
  end

  def config_path_from(argv)
    options = { config: DEFAULT_CONFIG }
    parser = OptionParser.new do |opts|
      opts.on("--config PATH", "Auto-updater config file") { |value| options[:config] = File.expand_path(value, ROOT) }
    end
    parser.parse!(argv)
    [options, argv]
  end

  def load_config(path)
    config = load_yaml(path, {})
    abort "Missing auto-updater config: #{relative(path)}" if config.empty?

    config
  end

  def publication_sources(config)
    Array(config.dig("publication_sync", "sources"))
  end

  def all_documents
    PublicationTools.active_documents.map do |doc|
      front_matter = doc.front_matter || {}
      topics = load_yaml(PublicationTools.data_path(:topics), {})
      highlights = load_yaml(PublicationTools.data_path(:highlights), {})
      {
        "slug" => doc.slug,
        "collection" => doc.collection,
        "path" => doc.path,
        "front_matter" => front_matter,
        "topics" => Array(topics[doc.slug]),
        "highlights" => Array(highlights[doc.slug])
      }
    end
  end

  def active_slug_set
    PublicationTools.active_documents.each_with_object({}) { |doc, memo| memo[doc.slug] = true }
  end

  def audit!(argv)
    options, rest = config_path_from(argv)
    usage! if rest.any?

    config = load_config(options[:config])
    errors = []
    warnings = []
    slugs = active_slug_set

    publication_sources(config).each_with_index do |source, index|
      unless source.is_a?(Hash)
        errors << "publication_sync.sources[#{index}] must be a mapping"
        next
      end

      kind = source["kind"].to_s
      errors << "publication_sync.sources[#{index}] missing `kind`" if blank?(kind)
      errors << "publication_sync.sources[#{index}] unsupported kind `#{kind}`" if !blank?(kind) && !SUPPORTED_SOURCE_KINDS.include?(kind)
      errors << "publication_sync.sources[#{index}] use `google_scholar_manual`, not automated Google Scholar scraping" if kind == "google_scholar"

      case kind
      when "arxiv"
        errors << "publication_sync.sources[#{index}] missing arXiv `id`" if blank?(source["id"])
        errors << "publication_sync.sources[#{index}] missing `topics`" if Array(source["topics"]).empty?
      when "bibtex", "dblp_bibtex", "semantic_scholar_bibtex", "google_scholar_manual"
        path = source["path"].to_s
        errors << "publication_sync.sources[#{index}] missing BibTeX `path`" if blank?(path)
        errors << "publication_sync.sources[#{index}] missing `topics`" if Array(source["topics"]).empty?
        errors << "publication_sync.sources[#{index}] BibTeX file not found: #{path}" if !blank?(path) && !File.exist?(File.expand_path(path, ROOT))
      end
    end

    selected = config["selected_publications"] || {}
    Array(selected["pinned"]).each do |slug|
      errors << "selected_publications.pinned unknown slug `#{slug}`" unless slugs[slug.to_s]
    end
    Array(selected["exclude"]).each do |slug|
      errors << "selected_publications.exclude unknown slug `#{slug}`" unless slugs[slug.to_s]
    end

    validate_content_workflows(config, errors)

    if !File.exist?(File.join(ROOT, "Gemfile")) || !File.read(File.join(ROOT, "Gemfile")).include?("jekyll-feed")
      warnings << "RSS feed plugin jekyll-feed was not found in Gemfile"
    end

    if errors.any?
      warn "Auto-updater audit failed:"
      errors.each { |error| warn "  - #{error}" }
      exit 1
    end

    if warnings.any?
      warn "Auto-updater audit warnings:"
      warnings.each { |warning| warn "  - #{warning}" }
    end

    puts "Auto-updater audit OK: #{publication_sources(config).size} configured publication sources."
  end

  def validate_content_workflows(config, errors)
    workflows = config["content_workflows"] || {}
    validate_group_data(workflows["group_data"], errors)
    validate_news_collection(workflows["news_collection"], errors)
    validate_template("scripts/templates/news.yml", errors)
    validate_template("scripts/templates/group-member.yml", errors)
    validate_template("scripts/templates/research-project.yml", errors)
  end

  def validate_group_data(relative_path, errors)
    path = File.expand_path(relative_path || "_data/group.yml", ROOT)
    unless File.exist?(path)
      errors << "group data file not found: #{relative(path)}"
      return
    end

    data = load_yaml(path, {})
    category_ids = Array(data["people_categories"]).map { |category| category["id"].to_s }
    Array(data["people"]).each_with_index do |person, index|
      errors << "#{relative(path)}: people[#{index}] missing `name`" if blank?(person["name"])
      errors << "#{relative(path)}: people[#{index}] missing `role`" if blank?(person["role"])
      group = person["group"].to_s
      errors << "#{relative(path)}: people[#{index}] missing `group`" if blank?(group)
      errors << "#{relative(path)}: people[#{index}] unknown group `#{group}`" if !blank?(group) && !category_ids.include?(group)
    end
  end

  def validate_news_collection(relative_path, errors)
    dir = File.expand_path(relative_path || "_news", ROOT)
    unless Dir.exist?(dir)
      errors << "news collection not found: #{relative(dir)}"
      return
    end

    Dir.glob(File.join(dir, "*.md")).sort.each do |path|
      front_matter = read_front_matter(path)
      if front_matter.nil?
        errors << "#{relative(path)}: missing YAML front matter"
        next
      end

      %w[date title summary].each do |field|
        errors << "#{relative(path)}: missing `#{field}`" if blank?(front_matter[field])
      end
    end
  end

  def validate_template(relative_path, errors)
    path = File.join(ROOT, relative_path)
    errors << "template file not found: #{relative_path}" unless File.exist?(path)
  end

  def read_front_matter(path)
    text = File.read(path)
    match = text.match(/\A---\s*\r?\n(.*?)\r?\n---\s*(?:\r?\n|\z)/m)
    return nil unless match

    PublicationTools.stringify_keys(YAML.safe_load(
      match[1],
      permitted_classes: [Date, Time],
      aliases: true
    ) || {})
  rescue Psych::SyntaxError => e
    raise "Invalid front matter in #{relative(path)}: #{e.message}"
  end

  def plan!(argv)
    options, rest = config_path_from(argv)
    usage! if rest.any?

    config = load_config(options[:config])
    docs = all_documents
    selected = load_yaml(FEATURED_PATH, [])
    sources = publication_sources(config)

    puts "Academic Website Auto-Updater v2 plan"
    puts "- Active publication documents: #{docs.size}"
    puts "- Configured publication sources: #{sources.size}"
    puts "- Featured publication slots: #{selected.size}"
    puts "- News feed: data-driven via _news and RSS via jekyll-feed"
    puts "- Group page: data-driven via _data/group.yml"
    puts "- Research projects: data-driven via _data/research_themes.yml"
    puts "- Deployment: GitHub Pages workflow is primary; Vercel config is optional"
    puts
    puts "Supported source workflow:"
    puts "- arXiv API import: automated metadata fetch"
    puts "- BibTeX import: exported BibTeX from DBLP, Semantic Scholar, Google Scholar, OpenReview, or publisher pages"
    puts "- Google Scholar: manual BibTeX export only, no scraping"

    return if sources.empty?

    puts
    puts "Configured sources:"
    sources.each_with_index do |source, index|
      label = source["id"] || source["path"] || "(missing id/path)"
      puts "- #{index + 1}. #{source["kind"]}: #{label}"
    end
  end

  def sync_publications!(argv)
    options = { config: DEFAULT_CONFIG, apply: false }
    parser = OptionParser.new do |opts|
      opts.on("--config PATH", "Auto-updater config file") { |value| options[:config] = File.expand_path(value, ROOT) }
      opts.on("--apply", "Write generated publication files and data") { options[:apply] = true }
    end
    parser.parse!(argv)
    usage! if argv.any?

    config = load_config(options[:config])
    sources = publication_sources(config)
    if sources.empty?
      puts "No publication sources configured in #{relative(options[:config])}; nothing to sync."
      return
    end

    sources.each do |source|
      process_publication_source(source, apply: options[:apply])
    end
  end

  def import_arxiv!(argv)
    options = import_options
    parser = import_parser(options)
    parser.parse!(argv)
    arxiv_id = argv.shift
    usage! if blank?(arxiv_id) || argv.any?
    abort "Missing topics. Pass --topics \"Topic A,Topic B\"." if options[:topics].empty?

    source = {
      "kind" => "arxiv",
      "id" => arxiv_id,
      "collection" => options[:collection],
      "slug" => options[:slug],
      "topics" => options[:topics]
    }
    process_publication_source(source, apply: options[:apply])
  end

  def import_bibtex!(argv)
    options = import_options
    parser = import_parser(options)
    parser.parse!(argv)
    path = argv.shift
    usage! if blank?(path) || argv.any?
    abort "Missing topics. Pass --topics \"Topic A,Topic B\"." if options[:topics].empty?

    source = {
      "kind" => "bibtex",
      "path" => path,
      "collection" => options[:collection],
      "slug" => options[:slug],
      "topics" => options[:topics]
    }
    process_publication_source(source, apply: options[:apply])
  end

  def import_options
    {
      apply: false,
      collection: nil,
      slug: nil,
      topics: []
    }
  end

  def import_parser(options)
    OptionParser.new do |opts|
      opts.on("--apply", "Write generated publication files and data") { options[:apply] = true }
      opts.on("--collection NAME", "publications or technical_reports") { |value| options[:collection] = value }
      opts.on("--slug SLUG", "Override generated slug") { |value| options[:slug] = value }
      opts.on("--topics LIST", "Comma-separated topics") { |value| options[:topics] = split_list(value) }
    end
  end

  def process_publication_source(source, apply:)
    kind = source["kind"].to_s
    case kind
    when "arxiv"
      data = ArxivSource.new.fetch(source.fetch("id"))
      data = merge_source_overrides(data, source)
      run_generator_with_data(data, apply: apply)
    when "bibtex", "dblp_bibtex", "semantic_scholar_bibtex", "google_scholar_manual"
      run_generator_with_bibtex(source, apply: apply)
    else
      abort "Unsupported publication source kind `#{kind}`."
    end
  end

  def merge_source_overrides(data, source)
    merged = data.merge(
      "collection" => source["collection"] || data["collection"],
      "topics" => Array(source["topics"]).map(&:to_s),
      "highlights" => Array(source["highlights"]).map(&:to_s)
    )
    merged["slug"] = source["slug"] unless blank?(source["slug"])
    merged["venue"] = source["venue"] unless blank?(source["venue"])
    merged["date"] = source["date"] unless blank?(source["date"])
    merged
  end

  def run_generator_with_data(data, apply:)
    Tempfile.create(["auto-updater-publication", ".yml"]) do |file|
      file.write(YAML.dump(data))
      file.flush
      args = [file.path]
      args << "--dry-run" unless apply
      PublicationTools::Generator.new(args).run
    end
  end

  def run_generator_with_bibtex(source, apply:)
    path = File.expand_path(source.fetch("path"), ROOT)
    abort "BibTeX file not found: #{relative(path)}" unless File.exist?(path)

    args = [path]
    args.concat(["--collection", source["collection"]]) unless blank?(source["collection"])
    args.concat(["--slug", source["slug"]]) unless blank?(source["slug"])
    args.concat(["--venue", source["venue"]]) unless blank?(source["venue"])
    args.concat(["--date", source["date"]]) unless blank?(source["date"])
    args.concat(["--topics", Array(source["topics"]).join(",")]) unless Array(source["topics"]).empty?
    args << "--dry-run" unless apply
    PublicationTools::Generator.new(args).run
  end

  def suggest_selected!(argv)
    options = { config: DEFAULT_CONFIG, apply: false }
    parser = OptionParser.new do |opts|
      opts.on("--config PATH", "Auto-updater config file") { |value| options[:config] = File.expand_path(value, ROOT) }
      opts.on("--apply", "Update _data/featured_publications.yml") { options[:apply] = true }
    end
    parser.parse!(argv)
    usage! if argv.any?

    config = load_config(options[:config])
    selected_config = config["selected_publications"] || {}
    limit = selected_config["limit"].to_i.positive? ? selected_config["limit"].to_i : 4
    pinned = Array(selected_config["pinned"]).map(&:to_s)
    exclude = Array(selected_config["exclude"]).map(&:to_s)
    preferred_topics = Array(selected_config["preferred_topics"]).map(&:to_s)

    documents = all_documents.reject { |doc| exclude.include?(doc.fetch("slug")) }
    scored = documents.map { |doc| [selection_score(doc, pinned, preferred_topics), doc.fetch("slug")] }
    suggestions = scored.sort_by { |score, slug| [-score, slug] }.map(&:last)
    selected = (pinned + suggestions).uniq.first(limit)

    puts "Suggested featured publications:"
    selected.each_with_index { |slug, index| puts "#{index + 1}. #{slug}" }

    return unless options[:apply]

    PublicationTools.write_yaml(FEATURED_PATH, selected)
    puts "Updated #{relative(FEATURED_PATH)}"
  end

  def selection_score(doc, pinned, preferred_topics)
    slug = doc.fetch("slug")
    front_matter = doc.fetch("front_matter")
    year = front_matter["pubtype"].to_i
    topic_matches = (doc.fetch("topics") & preferred_topics).size
    highlight_bonus = doc.fetch("highlights").empty? ? 0 : 50
    selected_bonus = pinned.include?(slug) ? 10_000 - pinned.index(slug) : 0
    technical_bonus = doc.fetch("collection") == "technical_reports" ? 2 : 0

    selected_bonus + (year * 10) + (topic_matches * 20) + highlight_bonus + technical_bonus
  end

  def split_list(value)
    value.to_s.split(",").map(&:strip).reject(&:empty?)
  end

  def slugify(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
  end

  class ArxivSource
    API_BASE = "https://export.arxiv.org/api/query"

    def fetch(arxiv_id)
      uri = URI(API_BASE)
      uri.query = URI.encode_www_form(id_list: arxiv_id)
      response = Net::HTTP.get_response(uri)
      abort "arXiv API failed for #{arxiv_id}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      entry = first_entry(response.body)
      abort "arXiv API returned no entry for #{arxiv_id}" unless entry

      title = compact(text_at(entry, "title"))
      abstract = compact(text_at(entry, "summary"))
      authors = author_names(entry)
      published = parse_date(text_at(entry, "published"))
      year = published[0, 4]
      abs_url = "https://arxiv.org/abs/#{arxiv_id}"
      citation_key = citation_key(authors, title, year)

      {
        "slug" => "#{citation_key}_arxiv_#{year}",
        "collection" => "technical_reports",
        "title" => title,
        "authors" => authors,
        "venue" => "arXiv",
        "date" => published,
        "year" => year,
        "links" => [{ "label" => "arXiv", "url" => abs_url }],
        "topics" => [],
        "abstract" => abstract,
        "bibtex" => bibtex(citation_key, title, authors, arxiv_id, year, abs_url)
      }
    end

    private

    def first_entry(xml)
      doc = REXML::Document.new(xml)
      find_element(doc.root, "entry")
    end

    def text_at(element, name)
      child = find_direct_child(element, name)
      child ? child.text.to_s : ""
    end

    def author_names(entry)
      names = []
      entry.each_element do |author|
        next unless author.name == "author"

        name = text_at(author, "name")
        names << compact(name) unless AutoUpdater.blank?(name)
      end
      names
    end

    def find_element(element, name)
      return element if element.respond_to?(:name) && element.name == name

      element.each_element do |child|
        found = find_element(child, name)
        return found if found
      end

      nil
    end

    def find_direct_child(element, name)
      element.each_element do |child|
        return child if child.name == name
      end

      nil
    end

    def compact(value)
      value.to_s.gsub(/\s+/, " ").strip
    end

    def parse_date(value)
      Date.parse(value.to_s).to_s
    rescue ArgumentError
      Date.today.to_s
    end

    def citation_key(authors, title, year)
      first_author = authors.first.to_s.split(/\s+/).last || "paper"
      first_word = title.to_s.downcase.scan(/[a-z0-9]+/).find { |word| word.length > 2 } || "paper"
      AutoUpdater.slugify("#{first_author}#{year}#{first_word}").gsub("_", "")
    end

    def bibtex(key, title, authors, arxiv_id, year, abs_url)
      <<~BIB.strip
        @article{#{key},
          title={#{title}},
          author={#{authors.join(" and ")}},
          journal={arXiv preprint arXiv:#{arxiv_id}},
          year={#{year}},
          url={#{abs_url}}
        }
      BIB
    end
  end
end

command = ARGV.shift

case command
when "audit"
  AutoUpdater.audit!(ARGV)
when "plan"
  AutoUpdater.plan!(ARGV)
when "sync-publications"
  AutoUpdater.sync_publications!(ARGV)
when "import-arxiv"
  AutoUpdater.import_arxiv!(ARGV)
when "import-bibtex"
  AutoUpdater.import_bibtex!(ARGV)
when "suggest-selected"
  AutoUpdater.suggest_selected!(ARGV)
else
  AutoUpdater.usage!
end
