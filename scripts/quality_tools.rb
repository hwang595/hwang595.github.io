#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "set"
require "uri"

begin
  require "nokogiri"
rescue LoadError
  warn "Missing Nokogiri. Run this through Bundler: bundle exec ruby scripts/quality_tools.rb audit"
  exit 1
end

module QualityTools
  ROOT = File.expand_path("..", __dir__)
  DEFAULT_SITE_DIR = File.join(ROOT, "_site")
  PAGE_IMAGE_BUDGET_BYTES = 1_500_000
  RENDERED_IMAGE_WARNING_BYTES = 800_000
  EMBEDDED_HTML_EXCLUDES = [
    "talkmap/map.html"
  ].freeze
  SAME_HOST_EXTERNAL_PREFIXES = [
    "/RU-CS-671-Fall2025/"
  ].freeze

  module_function

  def usage!
    warn <<~USAGE
      Usage:
        bundle exec ruby scripts/quality_tools.rb audit [site_dir]

      Checks generated HTML for accessibility basics, internal links, SEO tags,
      robots/sitemap output, and rendered image budgets.
    USAGE
    exit 1
  end

  def relative(path)
    Pathname.new(path).relative_path_from(Pathname.new(ROOT)).to_s
  rescue ArgumentError
    path.to_s
  end

  def blank?(value)
    value.nil? || value.to_s.strip.empty?
  end

  def audit!(argv)
    site_dir = argv.shift || DEFAULT_SITE_DIR
    usage! if argv.any?

    Auditor.new(site_dir).run
  end

  class Auditor
    def initialize(site_dir)
      @site_dir = File.expand_path(site_dir)
      @errors = []
      @warnings = []
      @documents = {}
      @page_image_bytes = Hash.new(0)
    end

    def run
      unless Dir.exist?(@site_dir)
        @errors << "#{QualityTools.relative(@site_dir)} does not exist. Run `make build` first."
        return report
      end

      load_documents
      check_html_documents
      check_internal_links
      check_robots_and_sitemap
      report
    end

    private

    def load_documents
      Dir.glob(File.join(@site_dir, "**", "*.html")).sort.each do |path|
        next if EMBEDDED_HTML_EXCLUDES.include?(site_relative(path))

        @documents[path] = Nokogiri::HTML(File.read(path))
      end
    end

    def check_html_documents
      @documents.each do |path, doc|
        next if redirect_page?(doc)

        check_page_shell(path, doc)
        check_accessibility(path, doc)
        check_rendered_images(path, doc)
      end
    end

    def check_page_shell(path, doc)
      html = doc.at("html")
      @errors << "#{label(path)}: html element is missing lang" if html && QualityTools.blank?(html["lang"])

      title = doc.at("title")
      @errors << "#{label(path)}: missing non-empty title" if title.nil? || QualityTools.blank?(title.text)

      description = doc.at('meta[name="description"]')
      @errors << "#{label(path)}: missing meta description" if description.nil? || QualityTools.blank?(description["content"])

      canonical = doc.at('link[rel="canonical"]')
      @errors << "#{label(path)}: missing canonical link" if canonical.nil? || QualityTools.blank?(canonical["href"])
    end

    def check_accessibility(path, doc)
      check_duplicate_ids(path, doc)
      check_images(path, doc)
      check_buttons(path, doc)
      check_links_have_names(path, doc)
      check_form_controls(path, doc)
    end

    def check_duplicate_ids(path, doc)
      ids = Hash.new { |hash, key| hash[key] = 0 }
      doc.css("[id]").each do |node|
        id = node["id"].to_s
        ids[id] += 1 unless QualityTools.blank?(id)
      end

      ids.each do |id, count|
        @errors << "#{label(path)}: duplicate id `#{id}` appears #{count} times" if count > 1
      end
    end

    def check_images(path, doc)
      doc.css("img").each do |image|
        next if decorative?(image)

        if image["alt"].nil?
          @errors << "#{label(path)}: image `#{image["src"]}` is missing alt text"
        elsif QualityTools.blank?(image["alt"])
          @warnings << "#{label(path)}: image `#{image["src"]}` has empty alt text"
        end
      end
    end

    def check_buttons(path, doc)
      doc.css("button").each do |button|
        next unless accessible_name(button).empty?

        @errors << "#{label(path)}: button is missing an accessible name"
      end
    end

    def check_links_have_names(path, doc)
      doc.css("a[href]").each do |link|
        next unless accessible_name(link).empty?

        @errors << "#{label(path)}: link to `#{link["href"]}` is missing an accessible name"
      end
    end

    def check_form_controls(path, doc)
      doc.css("input, select, textarea").each do |control|
        next if %w[hidden submit button reset image].include?(control["type"].to_s.downcase)
        next if control["aria-label"] || control["aria-labelledby"] || control["title"]

        id = control["id"].to_s
        has_label = !QualityTools.blank?(id) && doc.at("label[for='#{css_escape(id)}']")
        has_label ||= control.ancestors("label").any?
        @errors << "#{label(path)}: form control `#{control.name}` is missing a label" unless has_label
      end
    end

    def check_rendered_images(path, doc)
      doc.css("img[src]").each do |image|
        asset_path = local_asset_path(image["src"], path)
        next unless asset_path

        if !File.exist?(asset_path)
          @errors << "#{label(path)}: image file is missing: #{image["src"]}"
          next
        end

        size = File.size(asset_path)
        @page_image_bytes[path] += size
        if size > RENDERED_IMAGE_WARNING_BYTES
          @warnings << "#{label(path)}: rendered image `#{image["src"]}` is #{human_size(size)}"
        end
      end

      page_total = @page_image_bytes[path]
      if page_total > PAGE_IMAGE_BUDGET_BYTES
        @warnings << "#{label(path)}: rendered image budget is #{human_size(page_total)}"
      end
    end

    def check_internal_links
      @documents.each do |path, doc|
        next if redirect_page?(doc)

        doc.css("a[href]").each do |link|
          href = link["href"].to_s.strip
          next if ignored_href?(href)

          target = internal_target(path, href)
          next unless target

          if !File.exist?(target.fetch(:path))
            @errors << "#{label(path)}: broken internal link `#{href}`"
            next
          end

          next if QualityTools.blank?(target.fetch(:fragment))

          target_doc = @documents[target.fetch(:path)]
          next unless target_doc

          unless target_doc.at("[id='#{css_escape(target.fetch(:fragment))}']")
            @warnings << "#{label(path)}: internal link `#{href}` points to a missing fragment"
          end
        end
      end
    end

    def check_robots_and_sitemap
      robots_path = File.join(@site_dir, "robots.txt")
      sitemap_path = File.join(@site_dir, "sitemap.xml")

      if File.exist?(robots_path)
        robots = File.read(robots_path)
        @errors << "robots.txt: missing Sitemap directive" unless robots.match?(/^Sitemap:\s+\S+/)
      else
        @errors << "robots.txt: missing generated robots.txt"
      end

      if File.exist?(sitemap_path)
        sitemap = File.read(sitemap_path)
        @errors << "sitemap.xml: missing absolute loc URLs" unless sitemap.match?(%r{<loc>https?://[^<]+</loc>})
      else
        @errors << "sitemap.xml: missing generated sitemap"
      end
    end

    def internal_target(current_path, href)
      uri = URI.parse(href)
      return nil if uri.host && uri.host != "hwang595.github.io"

      fragment = uri.fragment.to_s
      path = uri.path.to_s
      if QualityTools.blank?(path)
        return { path: current_path, fragment: fragment }
      end

      path = path.start_with?("/") ? path : File.join(File.dirname(site_relative(current_path)), path)
      path = normalize_site_path(path)
      { path: path, fragment: fragment }
    rescue URI::InvalidURIError
      @errors << "#{label(current_path)}: invalid link URL `#{href}`"
      nil
    end

    def normalize_site_path(path)
      clean_path = Pathname.new("/#{path}").cleanpath.to_s.sub(%r{\A/}, "")
      candidates = []
      candidates << File.join(@site_dir, clean_path)
      candidates << File.join(@site_dir, clean_path, "index.html") unless clean_path.end_with?(".html")
      candidates << File.join(@site_dir, "#{clean_path}.html") unless clean_path.end_with?(".html")
      candidates.find { |candidate| File.exist?(candidate) } || candidates.first
    end

    def local_asset_path(src, current_path)
      uri = URI.parse(src.to_s)
      return nil if uri.host && uri.host != "hwang595.github.io"

      path = uri.path.to_s
      return nil if QualityTools.blank?(path)

      path = path.start_with?("/") ? path : File.join(File.dirname(site_relative(current_path)), path)
      File.join(@site_dir, Pathname.new("/#{path}").cleanpath.to_s.sub(%r{\A/}, ""))
    rescue URI::InvalidURIError
      nil
    end

    def ignored_href?(href)
      QualityTools.blank?(href) ||
        href.start_with?("mailto:", "tel:", "javascript:", "#", "data:") ||
        href.start_with?("//") ||
        same_host_external?(href) ||
        href.match?(%r{\Ahttps?://(?!hwang595\.github\.io)})
    end

    def same_host_external?(href)
      uri = URI.parse(href)
      return false unless uri.host == "hwang595.github.io"

      SAME_HOST_EXTERNAL_PREFIXES.any? { |prefix| uri.path.start_with?(prefix) }
    rescue URI::InvalidURIError
      false
    end

    def redirect_page?(doc)
      !doc.at('meta[http-equiv="refresh"]').nil? ||
        doc.css('meta[name="robots"]').any? { |meta| meta["content"].to_s.include?("noindex") }
    end

    def decorative?(image)
      image["role"].to_s == "presentation" || image["aria-hidden"].to_s == "true"
    end

    def accessible_name(node)
      [
        node["aria-label"],
        node["title"],
        node.text,
        node.css("img[alt]").map { |image| image["alt"] }.join(" ")
      ].compact.join(" ").gsub(/\s+/, " ").strip
    end

    def css_escape(value)
      value.to_s.gsub("\\", "\\\\\\").gsub("'", "\\\\'")
    end

    def site_relative(path)
      Pathname.new(path).relative_path_from(Pathname.new(@site_dir)).to_s
    end

    def label(path)
      QualityTools.relative(path)
    end

    def human_size(bytes)
      return "#{bytes} B" if bytes < 1024
      return format("%.1f KB", bytes / 1024.0) if bytes < 1024 * 1024

      format("%.1f MB", bytes / 1024.0 / 1024.0)
    end

    def report
      @warnings.uniq.each { |warning| warn "WARN #{warning}" }

      if @errors.any?
        warn "Quality audit failed:"
        @errors.uniq.each { |error| warn "  - #{error}" }
        exit 1
      end

      puts "Quality audit OK: #{@documents.size} HTML files, #{@warnings.uniq.size} warnings."
    end
  end
end

command = ARGV.shift

case command
when "audit"
  QualityTools.audit!(ARGV)
else
  QualityTools.usage!
end
