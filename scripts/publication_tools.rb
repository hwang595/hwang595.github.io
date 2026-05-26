#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "optparse"
require "yaml"

module PublicationTools
  ROOT = File.expand_path("..", __dir__)
  COLLECTION_DIRS = {
    "publications" => "_publications",
    "technical_reports" => "_technical_reports"
  }.freeze
  REQUIRED_FRONT_MATTER = %w[title date venue pubtype excerpt].freeze
  LINK_FRONT_MATTER_FIELDS = %w[link paperurl arxiv code project url].freeze
  DATA_FILES = {
    topics: "_data/publication_topics.yml",
    links: "_data/publication_links.yml",
    highlights: "_data/publication_highlights.yml",
    featured: "_data/featured_publications.yml",
    research_themes: "_data/research_themes.yml"
  }.freeze

  module_function

  def relative(path)
    path.to_s.sub("#{ROOT}/", "")
  end

  def blank?(value)
    value.nil? || value.to_s.strip.empty?
  end

  def load_yaml(path, default)
    return default unless File.exist?(path)

    loaded = YAML.safe_load(
      File.read(path),
      permitted_classes: [Date, Time],
      aliases: true
    )
    stringify_keys(loaded || default)
  rescue Psych::SyntaxError => e
    raise "Invalid YAML in #{relative(path)}: #{e.message}"
  end

  def stringify_keys(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, nested), memo|
        memo[key.to_s] = stringify_keys(nested)
      end
    when Array
      value.map { |nested| stringify_keys(nested) }
    else
      value
    end
  end

  def write_yaml(path, value)
    File.write(path, "#{YAML.dump(value)}")
  end

  def active_documents
    COLLECTION_DIRS.flat_map do |collection, dir|
      Dir.glob(File.join(ROOT, dir, "*.md")).sort.map do |path|
        Document.new(path, collection)
      end
    end
  end

  def data_path(name)
    File.join(ROOT, DATA_FILES.fetch(name))
  end

  def validate!
    documents = active_documents
    active_slugs = documents.map(&:slug)
    active_slug_set = active_slugs.each_with_object({}) { |slug, memo| memo[slug] = true }
    errors = []

    topics = load_yaml(data_path(:topics), {})
    links = load_yaml(data_path(:links), {})
    highlights = load_yaml(data_path(:highlights), {})
    featured = load_yaml(data_path(:featured), [])
    research_themes = load_yaml(data_path(:research_themes), {})

    documents.each do |doc|
      front_matter = doc.front_matter
      if front_matter.nil?
        errors << "#{relative(doc.path)}: missing YAML front matter"
        next
      end

      REQUIRED_FRONT_MATTER.each do |field|
        errors << "#{relative(doc.path)}: missing front matter field `#{field}`" if blank?(front_matter[field])
      end

      year = parsed_year(front_matter["date"])
      if year.nil?
        errors << "#{relative(doc.path)}: `date` must be parseable"
      elsif front_matter["pubtype"].to_s != year.to_s
        errors << "#{relative(doc.path)}: `pubtype` must match date year #{year}"
      end

      if doc.collection == "technical_reports" && front_matter["type"].to_s != "Technical report"
        errors << "#{relative(doc.path)}: technical reports need `type: \"Technical report\"`"
      end

      topic_values = topics[doc.slug]
      if !topic_values.is_a?(Array) || topic_values.empty?
        errors << "#{relative(doc.path)}: missing non-empty `_data/publication_topics.yml` entry"
      elsif topic_values.any? { |topic| blank?(topic) }
        errors << "#{relative(doc.path)}: topic entries cannot be blank"
      end

      link_values = links[doc.slug]
      unless has_any_link?(front_matter, link_values)
        errors << "#{relative(doc.path)}: missing link in `_data/publication_links.yml`, front matter, or excerpt"
      end

      Array(link_values).each_with_index do |entry, index|
        unless entry.is_a?(Hash)
          errors << "#{DATA_FILES[:links]}: #{doc.slug}[#{index}] must be a mapping"
          next
        end

        errors << "#{DATA_FILES[:links]}: #{doc.slug}[#{index}] missing `label`" if blank?(entry["label"])
        if blank?(entry["url"])
          errors << "#{DATA_FILES[:links]}: #{doc.slug}[#{index}] missing `url`"
        elsif !valid_link_url?(entry["url"])
          errors << "#{DATA_FILES[:links]}: #{doc.slug}[#{index}] has unsupported url `#{entry["url"]}`"
        end
      end
    end

    validate_known_keys(DATA_FILES[:topics], topics.keys, active_slug_set, errors)
    validate_known_keys(DATA_FILES[:links], links.keys, active_slug_set, errors)
    validate_known_keys(DATA_FILES[:highlights], highlights.keys, active_slug_set, errors)

    unless featured.is_a?(Array)
      errors << "#{DATA_FILES[:featured]}: expected a list of publication slugs"
    else
      featured.each do |slug|
        errors << "#{DATA_FILES[:featured]}: unknown featured slug `#{slug}`" unless active_slug_set[slug.to_s]
      end
    end

    validate_research_themes(research_themes, active_slug_set, errors)

    if errors.any?
      warn "Publication metadata validation failed:"
      errors.each { |error| warn "  - #{error}" }
      exit 1
    end

    puts "Publication metadata OK: #{documents.size} documents, #{topics.size} topic entries, #{links.size} link entries."
  end

  def validate_research_themes(data, active_slug_set, errors)
    return if data.nil? || data.empty?

    unless data.is_a?(Hash)
      errors << "#{DATA_FILES[:research_themes]}: expected a mapping"
      return
    end

    Array(data["selected_projects"]).each_with_index do |project, index|
      unless project.is_a?(Hash)
        errors << "#{DATA_FILES[:research_themes]}: selected_projects[#{index}] must be a mapping"
        next
      end

      slug = project["slug"].to_s
      if blank?(slug)
        errors << "#{DATA_FILES[:research_themes]}: selected_projects[#{index}] missing `slug`"
      elsif !active_slug_set[slug]
        errors << "#{DATA_FILES[:research_themes]}: selected_projects[#{index}] unknown publication slug `#{slug}`"
      end
    end

    Array(data["themes"]).each_with_index do |theme, index|
      unless theme.is_a?(Hash)
        errors << "#{DATA_FILES[:research_themes]}: themes[#{index}] must be a mapping"
        next
      end

      errors << "#{DATA_FILES[:research_themes]}: themes[#{index}] missing `id`" if blank?(theme["id"])
      errors << "#{DATA_FILES[:research_themes]}: themes[#{index}] missing `title`" if blank?(theme["title"])

      slugs = Array(theme["project_slugs"])
      if slugs.empty?
        errors << "#{DATA_FILES[:research_themes]}: themes[#{index}] missing `project_slugs`"
      end

      slugs.each do |slug|
        errors << "#{DATA_FILES[:research_themes]}: #{theme["id"] || "theme #{index}"} unknown publication slug `#{slug}`" unless active_slug_set[slug.to_s]
      end
    end
  end

  def validate_known_keys(label, keys, active_slug_set, errors)
    keys.each do |slug|
      errors << "#{label}: unknown publication slug `#{slug}`" unless active_slug_set[slug.to_s]
    end
  end

  def parsed_year(value)
    return value.year if value.respond_to?(:year)

    Date.parse(value.to_s).year
  rescue ArgumentError
    nil
  end

  def valid_link_url?(url)
    url.to_s.match?(%r{\A(https?://|/)})
  end

  def has_any_link?(front_matter, link_values)
    Array(link_values).any? ||
      LINK_FRONT_MATTER_FIELDS.any? { |field| !blank?(front_matter[field]) } ||
      front_matter["excerpt"].to_s.match?(/\]\((https?:\/\/|\/)/)
  end

  def usage!
    warn <<~USAGE
      Usage:
        ruby scripts/publication_tools.rb validate
        ruby scripts/publication_tools.rb new path/to/publication.yml [options]
        ruby scripts/publication_tools.rb new path/to/publication.bib [options]

      Common options for `new`:
        --collection publications|technical_reports
        --slug SLUG
        --venue VENUE
        --date YYYY-MM-DD
        --topics "Topic A,Topic B"
        --link-label LABEL
        --dry-run
        --force
    USAGE
    exit 1
  end

  class Document
    attr_reader :path, :collection

    def initialize(path, collection)
      @path = path
      @collection = collection
    end

    def slug
      File.basename(path, ".md")
    end

    def front_matter
      text = File.read(path)
      match = text.match(/\A---\s*\r?\n(.*?)\r?\n---\s*(?:\r?\n|\z)/m)
      return nil unless match

      PublicationTools.stringify_keys(YAML.safe_load(
        match[1],
        permitted_classes: [Date, Time],
        aliases: true
      ) || {})
    rescue Psych::SyntaxError => e
      raise "Invalid front matter in #{PublicationTools.relative(path)}: #{e.message}"
    end
  end

  class Generator
    def initialize(argv)
      @argv = argv.dup
      @options = {
        collection: nil,
        slug: nil,
        venue: nil,
        date: nil,
        topics: nil,
        link_label: nil,
        dry_run: false,
        force: false
      }
    end

    def run
      parser.parse!(@argv)
      input_path = @argv.shift
      abort "Missing input file. See `ruby scripts/publication_tools.rb`." if PublicationTools.blank?(input_path)
      abort "Input file does not exist: #{input_path}" unless File.exist?(input_path)

      data = publication_data(input_path)
      normalized = normalize(data)
      target_path = target_path(normalized)
      payload = render_publication(normalized)

      if @options[:dry_run]
        puts "Would write #{PublicationTools.relative(target_path)}"
        puts payload
        puts "Would upsert data keys for `#{normalized.fetch("slug")}`."
        return
      end

      if File.exist?(target_path) && !@options[:force]
        abort "#{PublicationTools.relative(target_path)} already exists. Pass --force to overwrite."
      end

      FileUtils.mkdir_p(File.dirname(target_path))
      File.write(target_path, payload)
      upsert_data(normalized)
      puts "Created #{PublicationTools.relative(target_path)}"
      puts "Updated publication data for `#{normalized.fetch("slug")}`."
    end

    private

    def parser
      OptionParser.new do |opts|
        opts.on("--collection NAME", "publications or technical_reports") { |value| @options[:collection] = value }
        opts.on("--slug SLUG", "Override generated slug") { |value| @options[:slug] = value }
        opts.on("--venue VENUE", "Override venue") { |value| @options[:venue] = value }
        opts.on("--date DATE", "Override date") { |value| @options[:date] = value }
        opts.on("--topics LIST", "Comma-separated topics") { |value| @options[:topics] = split_list(value) }
        opts.on("--link-label LABEL", "Label for BibTeX URL") { |value| @options[:link_label] = value }
        opts.on("--dry-run", "Preview writes without changing files") { @options[:dry_run] = true }
        opts.on("--force", "Overwrite an existing publication file") { @options[:force] = true }
      end
    end

    def publication_data(input_path)
      case File.extname(input_path).downcase
      when ".yml", ".yaml"
        PublicationTools.load_yaml(input_path, {})
      when ".bib"
        data_from_bibtex(File.read(input_path))
      else
        abort "Unsupported input format. Use YAML or BibTeX."
      end
    end

    def data_from_bibtex(text)
      entry_key = text[/@\w+\s*\{\s*([^,]+),/m, 1]
      fields = {}
      text.scan(/(\w+)\s*=\s*(\{(?:[^{}]|\{[^{}]*\})*\}|"[^"]*")\s*,?/m) do |field, value|
        fields[field.downcase] = clean_bib_value(value)
      end

      year = fields["year"]
      url = fields["url"]
      {
        "slug" => entry_key,
        "title" => fields["title"],
        "authors" => fields["author"].to_s.split(/\s+and\s+/).reject(&:empty?),
        "venue" => fields["booktitle"] || fields["journal"] || @options[:venue],
        "date" => @options[:date] || (year ? "#{year}-01-01" : nil),
        "year" => year,
        "links" => url ? [{ "label" => (@options[:link_label] || label_for_url(url)), "url" => url }] : [],
        "bibtex" => text.strip
      }
    end

    def clean_bib_value(value)
      cleaned = value.to_s.strip
      if (cleaned.start_with?("{") && cleaned.end_with?("}")) ||
         (cleaned.start_with?("\"") && cleaned.end_with?("\""))
        cleaned = cleaned[1...-1]
      end
      cleaned.gsub(/[{}]/, "").gsub(/\s+/, " ").strip
    end

    def normalize(data)
      data = PublicationTools.stringify_keys(data)
      collection = (@options[:collection] || data["collection"] || "publications").to_s
      unless COLLECTION_DIRS.key?(collection)
        abort "Unknown collection `#{collection}`. Use publications or technical_reports."
      end

      date = (@options[:date] || data["date"]).to_s
      year = (data["year"] || PublicationTools.parsed_year(date)).to_s
      venue = (@options[:venue] || data["venue"]).to_s
      title = data["title"].to_s
      slug = @options[:slug] || data["slug"] || slugify([title, venue, year].join(" "))
      topics = @options[:topics] || Array(data["topics"]).map(&:to_s)

      abort "Missing `title`." if PublicationTools.blank?(title)
      abort "Missing `date` or `year`." if PublicationTools.blank?(date) || PublicationTools.blank?(year)
      abort "Missing `venue`." if PublicationTools.blank?(venue)
      abort "Missing `topics`. Add topics in YAML or pass --topics." if topics.empty?

      authors = Array(data["authors"]).map(&:to_s).reject(&:empty?)
      links = normalize_links(data)

      {
        "slug" => slugify(slug),
        "collection" => collection,
        "title" => title,
        "authors" => authors,
        "venue" => venue,
        "date" => date,
        "year" => year,
        "excerpt" => data["excerpt"] || generated_excerpt(authors, venue, year),
        "type" => data["type"],
        "links" => links,
        "topics" => topics,
        "highlights" => Array(data["highlights"]).map(&:to_s).reject(&:empty?),
        "abstract" => data["abstract"],
        "bibtex" => data["bibtex"]
      }
    end

    def normalize_links(data)
      links = Array(data["links"]).map do |link|
        link = PublicationTools.stringify_keys(link)
        { "label" => link["label"], "url" => link["url"] }
      end

      if links.empty? && !PublicationTools.blank?(data["url"])
        links << { "label" => label_for_url(data["url"]), "url" => data["url"] }
      end
      links
    end

    def generated_excerpt(authors, venue, year)
      author_text = authors.empty? ? "" : "#{authors.join(", ")}, "
      "#{author_text}#{venue} #{year}."
    end

    def split_list(value)
      value.to_s.split(",").map(&:strip).reject(&:empty?)
    end

    def target_path(data)
      File.join(ROOT, COLLECTION_DIRS.fetch(data.fetch("collection")), "#{data.fetch("slug")}.md")
    end

    def render_publication(data)
      primary_link = data.fetch("links").first
      lines = ["---"]
      lines << "title: #{quoted(data.fetch("title"))}"
      lines << "excerpt: #{quoted(data.fetch("excerpt"))}"
      lines << "date: #{data.fetch("date")}"
      lines << "venue: #{quoted(data.fetch("venue"))}"
      lines << "pubtype: #{quoted(data.fetch("year"))}"
      if primary_link
        lines << "link: #{quoted(primary_link.fetch("url"))}"
        lines << "link_label: #{quoted(primary_link.fetch("label"))}"
      end
      if data.fetch("collection") == "technical_reports"
        lines << "type: #{quoted(data["type"] || "Technical report")}"
      elsif !PublicationTools.blank?(data["type"])
        lines << "type: #{quoted(data["type"])}"
      end
      lines << "excerpt_separator: \"\""
      lines.concat(block_value("abstract", data["abstract"]))
      lines.concat(block_value("bibtex", data["bibtex"]))
      lines << "---"
      lines << ""
      "#{lines.join("\n")}\n"
    end

    def quoted(value)
      "\"#{value.to_s.gsub("\\", "\\\\\\").gsub("\"", "\\\"")}\""
    end

    def block_value(key, value)
      return [] if PublicationTools.blank?(value)

      ["#{key}: |"] + value.to_s.rstrip.lines.map { |line| "  #{line.rstrip}" }
    end

    def upsert_data(data)
      slug = data.fetch("slug")
      upsert_hash(DATA_FILES[:topics], slug, data.fetch("topics"))
      upsert_hash(DATA_FILES[:links], slug, data.fetch("links")) if data.fetch("links").any?
      upsert_hash(DATA_FILES[:highlights], slug, data.fetch("highlights")) if data.fetch("highlights").any?
    end

    def upsert_hash(relative_path, slug, value)
      path = File.join(ROOT, relative_path)
      current = PublicationTools.load_yaml(path, {})
      current[slug] = value
      PublicationTools.write_yaml(path, current)
    end

    def label_for_url(url)
      case url.to_s
      when /openreview\.net/i
        "OpenReview"
      when /arxiv\.org/i
        "arXiv"
      when /biorxiv\.org/i
        "bioRxiv"
      when /github\.com/i
        "Code"
      else
        "Paper"
      end
    end

    def slugify(value)
      value.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
    end
  end
end

command = ARGV.shift

case command
when "validate"
  PublicationTools.validate!
when "new"
  PublicationTools::Generator.new(ARGV).run
else
  PublicationTools.usage!
end
