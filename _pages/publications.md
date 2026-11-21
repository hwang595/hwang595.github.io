---
layout: archive
title: "Publications"
description: "Journal articles, conference papers, and technical reports by Hongyi Wang across efficient ML systems, LLM infrastructure, biological foundation models, federated learning, and trustworthy ML."
permalink: /publications/
author_profile: true
---

{% include base_path %}

{% assign publications = site.publications | sort: "date" | reverse %}
{% assign journal_papers = publications | where: "type", "Journal article" %}
{% assign other_papers = publications | where_exp: "pub", "pub.type != 'Journal article'" %}
{% assign technical_reports = site.technical_reports | sort: "date" | reverse %}
{% assign publication_years = publications | map: "pubtype" | uniq | sort | reverse %}
{% assign recent_year_limit = 5 %}
{% assign recent_years = publication_years | slice: 0, recent_year_limit %}
{% assign publication_venues = publications | map: "venue" | uniq | sort %}
{% capture topic_pool %}{% for pub in publications %}{% assign pub_key = pub.path | split: "/" | last | replace: ".md", "" %}{% assign pub_topics = site.data.publication_topics[pub_key] %}{% for topic in pub_topics %}{{ topic | strip }}|{% endfor %}{% endfor %}{% endcapture %}
{% assign filter_topics = topic_pool | split: "|" | uniq | sort %}

<div class="publication-browser" data-publication-browser>
  <div class="publication-browser__intro">
    <p class="publications-intro">
      Selected and recent work across efficient ML systems, LLM infrastructure, MoE/RL post-training,
      biological foundation models, federated learning, optimization, and trustworthy machine learning.
    </p>
    <div class="publication-browser__stats">
      <span><strong>{{ publications | size }}</strong> papers</span>
      <span><strong>{{ publication_years | size }}</strong> years</span>
      <span><strong>{{ publication_venues | size }}</strong> venues</span>
      <span><strong>{{ technical_reports | size }}</strong> technical reports</span>
    </div>
  </div>

  <div class="publication-controls" aria-label="Publication filters">
    <label class="publication-search">
      <span>Search</span>
      <input type="search" data-publication-search placeholder="Title, author, venue, or topic">
    </label>

    <div class="publication-filter-group" data-filter-group="year">
      <span>Year</span>
      <button type="button" class="is-active" aria-pressed="true" data-publication-filter="year" data-value="all">All</button>
      {% for year in publication_years limit:recent_year_limit %}
        <button type="button" aria-pressed="false" data-publication-filter="year" data-value="{{ year }}">{{ year }}</button>
      {% endfor %}
      {% if publication_years.size > recent_year_limit %}
        <button type="button" aria-pressed="false" data-publication-filter="year" data-value="earlier">Earlier</button>
      {% endif %}
    </div>

    <div class="publication-filter-group" data-filter-group="venue">
      <span>Venue</span>
      <button type="button" class="is-active" aria-pressed="true" data-publication-filter="venue" data-value="all">All</button>
      {% for venue in publication_venues %}
        <button type="button" aria-pressed="false" data-publication-filter="venue" data-value="{{ venue | slugify }}">{{ venue }}</button>
      {% endfor %}
    </div>

    <div class="publication-filter-group" data-filter-group="topic">
      <span>Topic</span>
      <button type="button" class="is-active" aria-pressed="true" data-publication-filter="topic" data-value="all">All</button>
      {% for topic in filter_topics %}
        {% unless topic == "" %}
          <button type="button" aria-pressed="false" data-publication-filter="topic" data-value="{{ topic | slugify }}">{{ topic }}</button>
        {% endunless %}
      {% endfor %}
    </div>
  </div>

  <p class="publication-result-count" aria-live="polite">
    Showing <strong data-publication-count>{{ publications | size }}</strong> publications, including accepted papers. Technical reports are listed separately below and are not filtered.
  </p>

  <div class="publication-no-results" data-publication-empty hidden>
    No publications match the current filters.
  </div>

  <nav class="publication-category-nav" aria-label="Publication categories">
    {% if journal_papers.size > 0 %}<a href="#journal-papers">Journal papers</a>{% endif %}
    <a href="#conference-papers">Conference and other papers</a>
    {% if technical_reports.size > 0 %}<a href="#technical-reports">Technical reports</a>{% endif %}
  </nav>

  {% if journal_papers.size > 0 %}
    <section class="publication-category" id="journal-papers" data-publication-year-group>
      <h2 class="publication-category__title">Journal papers</h2>
      <div class="publication-list">
        {% for pub in journal_papers %}
          {% assign journal_era = "earlier" %}
          {% if recent_years contains pub.pubtype %}{% assign journal_era = "recent" %}{% endif %}
          {% include publication-card.html publication=pub era=journal_era %}
        {% endfor %}
      </div>
    </section>
  {% endif %}

  <div class="publication-year-list publication-category" id="conference-papers" data-publication-year-group>
    <h2 class="publication-category__title">Conference and other papers</h2>
    {% for year in publication_years limit:recent_year_limit %}
      {% assign year_papers = other_papers | where: "pubtype", year %}
      {% if year_papers.size > 0 %}
      <section class="publication-year-group" data-publication-year-group>
        <h3 class="publication-year">{{ year }}</h3>
        <div class="publication-list">
          {% for pub in other_papers %}
            {% if pub.pubtype == year %}
              {% include publication-card.html publication=pub era="recent" %}
            {% endif %}
          {% endfor %}
        </div>
      </section>
      {% endif %}
    {% endfor %}
  </div>

  {% if technical_reports.size > 0 %}
    <section class="technical-reports" id="technical-reports">
      <div class="technical-reports__header">
        <p class="home-section__eyebrow">Technical reports</p>
        <h2>Technical Reports</h2>
        <p>Solid preprints, technical reports, and workshop manuscripts that complement the peer-reviewed publication list above.</p>
      </div>
      <div class="technical-report-list">
        {% for report in technical_reports %}
          {% include publication-card.html publication=report filterable=false %}
        {% endfor %}
      </div>
    </section>
  {% endif %}

  {% if publication_years.size > recent_year_limit %}
    <details class="publication-earlier" data-publication-earlier>
      <summary>
        <span>Earlier Publications</span>
        <small>Conference and other work before the recent five publication years</small>
      </summary>
      <div class="publication-earlier__groups">
        {% for year in publication_years offset:recent_year_limit %}
          {% assign year_papers = other_papers | where: "pubtype", year %}
          {% if year_papers.size > 0 %}
          <section class="publication-year-group" data-publication-year-group>
            <h2 class="publication-year">{{ year }}</h2>
            <div class="publication-list">
              {% for pub in other_papers %}
                {% if pub.pubtype == year %}
                  {% include publication-card.html publication=pub era="earlier" %}
                {% endif %}
              {% endfor %}
            </div>
          </section>
          {% endif %}
        {% endfor %}
      </div>
    </details>
  {% endif %}
</div>

<script src="{{ '/assets/js/publications.js' | relative_url }}"></script>
