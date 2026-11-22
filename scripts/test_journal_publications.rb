#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "nokogiri"
require_relative "publication_tools"

def check(condition, message)
  raise message unless condition
end

fixture = {
  "type" => "Journal article", "status" => "accepted",
  "accepted_date" => "2026-11-13", "date" => "2026-11-13"
}
check(PublicationTools.accepted_journal?(fixture), "Accepted journal should allow a pending public URL")
[
  { "type" => "Technical report" },
  { "status" => "published" },
  { "accepted_date" => nil },
  { "accepted_date" => "2026-02-30" },
  { "date" => "2026-11-14" }
].each do |override|
  check(!PublicationTools.accepted_journal?(fixture.merge(override)), "Invalid acceptance metadata: #{override}")
end

generator = PublicationTools::Generator.new([])
data = generator.send(:normalize, fixture.merge(
  "title" => "Test journal article", "venue" => "Test journal",
  "authors" => ["First Author", "Second Author"], "topics" => ["Test topic"],
  "excerpt" => "First Author and Second Author. Accepted at Test journal."
))
generated = YAML.safe_load(generator.send(:render_publication, data).split("---", 3)[1], permitted_classes: [Date])
check(generated["authors"] == data["authors"], "Generator lost author order")
check(PublicationTools.accepted_journal?(generated), "Generator lost acceptance metadata")

root = PublicationTools::ROOT
home = Nokogiri::HTML(File.read(File.join(root, "_site/index.html")))
listing = Nokogiri::HTML(File.read(File.join(root, "_site/publications/index.html")))
journals = PublicationTools.active_documents.select do |doc|
  doc.collection == "publications" && doc.front_matter["type"] == "Journal article"
end
check(listing.css("#journal-papers [data-publication-card]").size == journals.size, "Journal listing count mismatch")
check(home.css("#journal-papers .publication-card").size == [journals.size, 3].min, "Homepage journal count mismatch")

journals.each do |doc|
  metadata = doc.front_matter
  cards = listing.css("[data-publication-card]").select { |card| card.at(".publication-card__title").text.strip == metadata["title"] }
  check(cards.size == 1, "Journal article must appear exactly once in the filtered list: #{doc.slug}")
  check(cards.first.ancestors.any? { |node| node["id"] == "journal-papers" }, "Journal article is outside its section")
  check(cards.first.at(".pub-badge--journal"), "Missing journal classification")
  next unless PublicationTools.accepted_journal?(metadata)

  check(cards.first.at(".publication-card__status").text.include?("Publication forthcoming"), "Missing acceptance notice")
  detail = Nokogiri::HTML(File.read(File.join(root, "_site/publications", doc.slug, "index.html")))
  check(detail.css('[itemprop="datePublished"], [property="article:published_time"]').empty?, "Acceptance must not imply publication")
  schema = detail.css('script[type="application/ld+json"]').map { |node| JSON.parse(node.text) }.find { |item| item["@type"] == "ScholarlyArticle" }
  check(schema["creativeWorkStatus"] == "Accepted" && !schema.key?("datePublished"), "Incorrect accepted article structured data")
  check(schema["author"].map { |author| author["name"] } == metadata["authors"], "Structured data lost ordered authors")
end

puts "Journal publication checks OK: metadata, generation, categorization, and acceptance semantics."
