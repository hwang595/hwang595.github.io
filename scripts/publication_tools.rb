#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "net/http"
require "openssl"
require "optparse"
require "set"
require "uri"
require "yaml"

module PublicationTools
  ROOT = File.expand_path("..", __dir__)
  COLLECTION_DIRS = {
    "publications" => "_publications",
    "technical_reports" => "_technical_reports"
  }.freeze
  REQUIRED_FRONT_MATTER = %w[title date venue pubtype excerpt].freeze
  LINK_FRONT_MATTER_FIELDS = %w[link paperurl arxiv code project url].freeze
  HARD_BROKEN_LINK_CODES = [404, 410].freeze
  VENUE_ALIASES = [
    [/learning representations|ICLR/i, "ICLR"],
    [/international conference on machine learning|ICML/i, "ICML"],
    [/neural information processing systems|neurips|nips/i, "NeurIPS"],
    [/conference on language modeling|COLM/i, "COLM"],
    [/machine learning and systems|MLSys/i, "MLSys"],
    [/empirical methods in natural language processing|EMNLP/i, "EMNLP"],
    [/north american chapter.*association for computational linguistics|NAACL/i, "NAACL"],
    [/association for computational linguistics|ACL/i, "ACL"],
    [/international conference on robotics and automation|IROS/i, "IROS"],
    [/arxiv/i, "arXiv"],
    [/biorxiv/i, "bioRxiv"]
  ].freeze
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
    title_index = Hash.new { |hash, key| hash[key] = [] }
    errors = []
    warnings = []

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

      title_key = normalized_title(front_matter["title"])
      title_index[title_key] << doc unless blank?(title_key)

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
    validate_duplicate_titles(title_index, errors)
    validate_duplicate_link_urls(links, warnings)

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

    if warnings.any?
      warn "Publication metadata warnings:"
      warnings.each { |warning| warn "  - #{warning}" }
    end

    puts "Publication metadata OK: #{documents.size} documents, #{topics.size} topic entries, #{links.size} link entries."
  end

  def validate_duplicate_titles(title_index, errors)
    title_index.each_value do |docs|
      next if docs.size < 2

      errors << "duplicate publication title across #{docs.map { |doc| relative(doc.path) }.join(", ")}"
    end
  end

  def validate_duplicate_link_urls(links, warnings)
    links.each do |slug, entries|
      url_index = Hash.new { |hash, key| hash[key] = [] }
      Array(entries).each do |entry|
        next unless entry.is_a?(Hash)

        normalized = normalize_url(entry["url"])
        next if blank?(normalized)

        url_index[normalized] << entry["label"].to_s
      end

      url_index.each do |url, labels|
        next if labels.size < 2

        warnings << "#{DATA_FILES[:links]}: #{slug} repeats #{url} across labels #{labels.join(", ")}"
      end
    end
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

  def normalized_title(value)
    value.to_s.downcase.gsub(/&amp;/, "&").gsub(/[^a-z0-9]+/, " ").strip
  end

  def normalize_url(value)
    value.to_s.strip.sub(%r{\Ahttp://}i, "https://").sub(%r{/\z}, "")
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

  def collect_publication_links
    links_data = load_yaml(data_path(:links), {})
    seen = Set.new
    links = []

    active_documents.each do |doc|
      front_matter = doc.front_matter || {}
      Array(links_data[doc.slug]).each do |entry|
        next unless entry.is_a?(Hash)

        add_link_reference(links, seen, doc.slug, entry["label"], entry["url"], DATA_FILES[:links])
      end

      LINK_FRONT_MATTER_FIELDS.each do |field|
        add_link_reference(links, seen, doc.slug, field, front_matter[field], relative(doc.path)) unless blank?(front_matter[field])
      end
    end

    links
  end

  def add_link_reference(links, seen, slug, label, url, source)
    return if blank?(url)

    key = [slug.to_s, normalize_url(url)]
    return if seen.include?(key)

    seen << key
    links << {
      "slug" => slug.to_s,
      "label" => label.to_s,
      "url" => url.to_s,
      "source" => source.to_s
    }
  end

  def check_links!(argv)
    options = {
      dry_run: false,
      timeout: 10,
      limit: nil,
      only: nil
    }

    parser = OptionParser.new do |opts|
      opts.on("--dry-run", "List links without making network requests") { options[:dry_run] = true }
      opts.on("--timeout SECONDS", Integer, "Per-request timeout, default 10") { |value| options[:timeout] = value }
      opts.on("--limit N", Integer, "Check only the first N links") { |value| options[:limit] = value }
      opts.on("--only TEXT", "Only check URLs containing TEXT") { |value| options[:only] = value }
    end
    parser.parse!(argv)

    links = collect_publication_links
    links = links.select { |link| link["url"].include?(options[:only]) } if options[:only]
    links = links.first(options[:limit]) if options[:limit]

    if options[:dry_run]
      puts "Publication link inventory: #{links.size} links"
      links.each do |link|
        puts "- #{link["slug"]}: #{link["label"]} #{link["url"]}"
      end
      return
    end

    LinkChecker.new(timeout: options[:timeout]).run(links)
  end

  def usage!
    warn <<~USAGE
      Usage:
        ruby scripts/publication_tools.rb validate
        ruby scripts/publication_tools.rb check-links [--dry-run] [--timeout 10]
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
        --allow-duplicate
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

  class LinkChecker
    REDIRECT_CODES = [301, 302, 303, 307, 308].freeze

    def initialize(timeout:, max_redirects: 4)
      @timeout = timeout
      @max_redirects = max_redirects
    end

    def run(links)
      failures = []
      warnings = []

      $stdout.sync = true
      puts "Checking #{links.size} publication links..."
      links.each do |link|
        result = check_url(link.fetch("url"))
        message = "#{link.fetch("slug")} #{link.fetch("label")}: #{link.fetch("url")} - #{result.fetch(:message)}"

        case result.fetch(:status)
        when :ok
          puts "OK #{message}"
        when :warning
          warnings << message
          warn "WARN #{message}"
        else
          failures << message
          warn "FAIL #{message}"
        end
      end

      puts "Link check complete: #{links.size - warnings.size - failures.size} OK, #{warnings.size} warnings, #{failures.size} failures."
      if failures.any?
        warn "Hard failures are limited to clearly broken links such as 404/410 or invalid URLs."
        exit 1
      end
    end

    private

    def check_url(url, redirects = 0)
      return check_local_url(url) if url.to_s.start_with?("/")

      uri = URI.parse(url.to_s)
      return failed("invalid HTTP URL") unless uri.is_a?(URI::HTTP) && !PublicationTools.blank?(uri.host)

      response = request(uri, Net::HTTP::Head)
      response = request(uri, Net::HTTP::Get) if fallback_to_get?(response)

      code = response.code.to_i
      if REDIRECT_CODES.include?(code) && response["location"]
        return warning("redirect loop after #{@max_redirects} redirects") if redirects >= @max_redirects

        return check_url(URI.join(uri, response["location"]).to_s, redirects + 1)
      end

      return ok("HTTP #{code}") if code.between?(200, 399)
      return failed("HTTP #{code}") if HARD_BROKEN_LINK_CODES.include?(code)

      warning("HTTP #{code}")
    rescue URI::InvalidURIError
      failed("invalid URL")
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
      warning("timed out")
    rescue SocketError => e
      warning("network error: #{e.message}")
    rescue OpenSSL::SSL::SSLError => e
      warning("TLS error: #{e.message}")
    rescue StandardError => e
      warning("#{e.class}: #{e.message}")
    end

    def request(uri, request_class)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: @timeout,
        read_timeout: @timeout
      ) do |http|
        request = request_class.new(uri)
        request["User-Agent"] = "hwang595.github.io-publication-link-check/1.0"
        request["Range"] = "bytes=0-0" if request_class == Net::HTTP::Get
        http.request(request)
      end
    end

    def fallback_to_get?(response)
      [403, 405, 501].include?(response.code.to_i)
    end

    def check_local_url(url)
      local_path = url.to_s.sub(%r{\A/}, "")
      candidates = [
        File.join(ROOT, local_path),
        File.join(ROOT, local_path, "index.html"),
        File.join(ROOT, "_site", local_path),
        File.join(ROOT, "_site", local_path, "index.html")
      ]

      return ok("local path found") if candidates.any? { |path| File.exist?(path) }

      warning("local path not found before build")
    end

    def ok(message)
      { status: :ok, message: message }
    end

    def warning(message)
      { status: :warning, message: message }
    end

    def failed(message)
      { status: :failed, message: message }
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
        force: false,
        allow_duplicate: false
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

      check_duplicate_publication!(normalized, target_path) unless @options[:allow_duplicate]

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
        opts.on("--allow-duplicate", "Allow a matching existing title") { @options[:allow_duplicate] = true }
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
      entry = parse_bibtex_entry(text)
      fields = entry.fetch("fields")
      year = inferred_year(fields)
      url = inferred_url(fields)
      venue = @options[:venue] || inferred_venue(fields, url)
      links = inferred_links(fields, url)

      {
        "slug" => inferred_slug(entry.fetch("key"), fields, venue, year),
        "collection" => inferred_collection(entry.fetch("type"), fields, venue, url),
        "title" => fields["title"],
        "authors" => fields["author"].to_s.split(/\s+and\s+/).reject(&:empty?),
        "venue" => venue,
        "date" => @options[:date] || inferred_date(fields, year),
        "year" => year,
        "links" => links,
        "bibtex" => text.strip
      }
    end

    def parse_bibtex_entry(text)
      source = text.to_s.strip
      match = source.match(/@([[:alpha:]][[:alnum:]_-]*)\s*([\{\(])/)
      abort "No BibTeX entry found." unless match

      entry_type = match[1].downcase
      entry_closer = match[2] == "{" ? "}" : ")"
      cursor = skip_whitespace(source, match.end(0))
      key_end = source.index(",", cursor)
      abort "BibTeX entry is missing a citation key." unless key_end

      key = source[cursor...key_end].to_s.strip
      cursor = key_end + 1
      fields = {}

      loop do
        cursor = skip_field_separators(source, cursor)
        break if cursor >= source.length || source[cursor] == entry_closer

        field_match = source.match(/\G([[:alnum:]_:-]+)\s*=/m, cursor)
        abort "Could not parse BibTeX field near: #{source[cursor, 40]}" unless field_match

        field_name = field_match[1].downcase
        cursor = skip_whitespace(source, field_match.end(0))
        raw_value, cursor = read_bib_value(source, cursor, entry_closer)
        fields[field_name] = clean_bib_value(raw_value)
      end

      { "type" => entry_type, "key" => key, "fields" => fields }
    end

    def skip_whitespace(source, cursor)
      cursor += 1 while cursor < source.length && source[cursor].match?(/\s/)
      cursor
    end

    def skip_field_separators(source, cursor)
      cursor += 1 while cursor < source.length && source[cursor].match?(/[\s,]/)
      cursor
    end

    def read_bib_value(source, cursor, entry_closer)
      case source[cursor]
      when "{"
        read_braced_value(source, cursor)
      when "\""
        read_quoted_value(source, cursor)
      else
        start = cursor
        cursor += 1 while cursor < source.length && source[cursor] != "," && source[cursor] != entry_closer
        [source[start...cursor].to_s.strip, cursor]
      end
    end

    def read_braced_value(source, cursor)
      depth = 0
      start = cursor

      while cursor < source.length
        char = source[cursor]
        depth += 1 if char == "{"
        depth -= 1 if char == "}"
        cursor += 1
        break if depth.zero?
      end

      abort "Unclosed braced BibTeX value." unless depth.zero?

      [source[start...cursor], cursor]
    end

    def read_quoted_value(source, cursor)
      start = cursor
      cursor += 1

      while cursor < source.length
        char = source[cursor]
        escaped = cursor.positive? && source[cursor - 1] == "\\"
        cursor += 1
        break if char == "\"" && !escaped
      end

      abort "Unclosed quoted BibTeX value." unless source[cursor - 1] == "\""

      [source[start...cursor], cursor]
    end

    def clean_bib_value(value)
      cleaned = value.to_s.strip
      if (cleaned.start_with?("{") && cleaned.end_with?("}")) ||
         (cleaned.start_with?("\"") && cleaned.end_with?("\""))
        cleaned = cleaned[1...-1]
      end
      cleaned
        .gsub(/\\([&%$#_{}])/, "\\1")
        .gsub(/[{}]/, "")
        .gsub(/\s+/, " ")
        .strip
    end

    def inferred_year(fields)
      fields["year"] || fields["date"].to_s[/\b(19|20)\d{2}\b/]
    end

    def inferred_date(fields, year)
      return fields["date"] if fields["date"].to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      return "#{year}-01-01" unless PublicationTools.blank?(year)

      nil
    end

    def inferred_venue(fields, url)
      source = fields["booktitle"] || fields["journal"] || fields["venue"] || fields["publisher"] || fields["archiveprefix"]
      canonical_venue(source) || preprint_venue(url, fields) || source
    end

    def canonical_venue(value)
      return nil if PublicationTools.blank?(value)

      match = VENUE_ALIASES.find { |pattern, _label| value.to_s.match?(pattern) }
      match ? match[1] : value
    end

    def preprint_venue(url, fields)
      return "arXiv" if url.to_s.match?(/arxiv\.org/i) || fields["archiveprefix"].to_s.match?(/arxiv/i)
      return "bioRxiv" if url.to_s.match?(/biorxiv\.org/i)

      nil
    end

    def inferred_url(fields)
      return fields["url"] unless PublicationTools.blank?(fields["url"])
      return "https://doi.org/#{fields["doi"]}" unless PublicationTools.blank?(fields["doi"])

      eprint = fields["eprint"].to_s
      if fields["archiveprefix"].to_s.match?(/arxiv/i) && !PublicationTools.blank?(eprint)
        return "https://arxiv.org/abs/#{eprint}"
      end

      nil
    end

    def inferred_links(fields, url)
      links = []
      links << { "label" => (@options[:link_label] || label_for_url(url)), "url" => url } unless PublicationTools.blank?(url)

      doi_url = "https://doi.org/#{fields["doi"]}" unless PublicationTools.blank?(fields["doi"])
      if doi_url && links.none? { |link| PublicationTools.normalize_url(link["url"]) == PublicationTools.normalize_url(doi_url) }
        links << { "label" => "DOI", "url" => doi_url }
      end

      links
    end

    def inferred_collection(entry_type, fields, venue, url)
      return @options[:collection] unless PublicationTools.blank?(@options[:collection])

      peer_reviewed = !PublicationTools.blank?(fields["booktitle"]) ||
        (!PublicationTools.blank?(fields["journal"]) && !%w[arXiv bioRxiv].include?(venue.to_s))
      return "technical_reports" if %w[misc unpublished techreport].include?(entry_type)
      return "technical_reports" if preprint_venue(url, fields) && !peer_reviewed

      "publications"
    end

    def inferred_slug(entry_key, fields, venue, year)
      return entry_key unless PublicationTools.blank?(entry_key)

      first_author = fields["author"].to_s.split(/\s+and\s+/).first.to_s.split(/\s+/).last
      slugify([first_author, short_venue_for_slug(venue), year, fields["title"]].compact.join(" "))
    end

    def short_venue_for_slug(venue)
      venue.to_s.gsub(/[^A-Za-z0-9]+/, " ").split.first(3).join(" ")
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
      author_text = authors.empty? ? "" : "#{human_join(authors)}, "
      "#{author_text}#{venue} #{year}."
    end

    def human_join(values)
      case values.size
      when 0
        ""
      when 1
        values.first
      when 2
        values.join(" and ")
      else
        "#{values[0...-1].join(", ")}, and #{values.last}"
      end
    end

    def split_list(value)
      value.to_s.split(",").map(&:strip).reject(&:empty?)
    end

    def target_path(data)
      File.join(ROOT, COLLECTION_DIRS.fetch(data.fetch("collection")), "#{data.fetch("slug")}.md")
    end

    def check_duplicate_publication!(data, target_path)
      title_key = PublicationTools.normalized_title(data.fetch("title"))

      PublicationTools.active_documents.each do |doc|
        next if File.expand_path(doc.path) == File.expand_path(target_path)

        front_matter = doc.front_matter || {}
        next unless PublicationTools.normalized_title(front_matter["title"]) == title_key

        abort "Possible duplicate publication title found in #{PublicationTools.relative(doc.path)}. Pass --allow-duplicate to continue."
      end
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

if $PROGRAM_NAME == __FILE__
  command = ARGV.shift

  case command
  when "validate"
    PublicationTools.validate!
  when "check-links"
    PublicationTools.check_links!(ARGV)
  when "new"
    PublicationTools::Generator.new(ARGV).run
  else
    PublicationTools.usage!
  end
end
