---
layout: archive
title: "Publications"
permalink: /publications/
author_profile: true
---

{% include base_path %}

{% assign publications = site.publications | sort: "date" | reverse %}
{% assign publication_years = publications | map: "pubtype" | uniq | sort | reverse %}
{% assign publication_venues = publications | map: "venue" | uniq | sort %}
{% assign filter_topics = "LLM Systems|Federated Learning|Distributed Training|Optimization|Model Compression|Privacy & Security|Open Models|Data & Evaluation|ML Systems|Robotics" | split: "|" %}

<div class="publication-browser" data-publication-browser>
  <div class="publication-browser__intro">
    <p class="publications-intro">
      Selected and recent work across efficient ML systems, LLM infrastructure, federated learning,
      optimization, and trustworthy machine learning.
    </p>
    <div class="publication-browser__stats">
      <span><strong>{{ publications | size }}</strong> papers</span>
      <span><strong>{{ publication_years | size }}</strong> years</span>
      <span><strong>{{ publication_venues | size }}</strong> venues</span>
    </div>
  </div>

  <div class="publication-controls" aria-label="Publication filters">
    <label class="publication-search">
      <span>Search</span>
      <input type="search" data-publication-search placeholder="Title, author, venue, or topic">
    </label>

    <div class="publication-filter-group" data-filter-group="year">
      <span>Year</span>
      <button type="button" class="is-active" data-publication-filter="year" data-value="all">All</button>
      {% for year in publication_years %}
        <button type="button" data-publication-filter="year" data-value="{{ year }}">{{ year }}</button>
      {% endfor %}
    </div>

    <div class="publication-filter-group" data-filter-group="venue">
      <span>Venue</span>
      <button type="button" class="is-active" data-publication-filter="venue" data-value="all">All</button>
      {% for venue in publication_venues %}
        <button type="button" data-publication-filter="venue" data-value="{{ venue | slugify }}">{{ venue }}</button>
      {% endfor %}
    </div>

    <div class="publication-filter-group" data-filter-group="topic">
      <span>Topic</span>
      <button type="button" class="is-active" data-publication-filter="topic" data-value="all">All</button>
      {% for topic in filter_topics %}
        <button type="button" data-publication-filter="topic" data-value="{{ topic | slugify }}">{{ topic }}</button>
      {% endfor %}
    </div>
  </div>

  <p class="publication-result-count" aria-live="polite">
    Showing <strong data-publication-count>{{ publications | size }}</strong> publications
  </p>

  <div class="publication-no-results" data-publication-empty hidden>
    No publications match the current filters.
  </div>

  <div class="publication-year-list">
    {% for year in publication_years %}
      <section class="publication-year-group" data-publication-year-group>
        <h2 class="publication-year">{{ year }}</h2>
        <div class="publication-list">
          {% for pub in publications %}
            {% if pub.pubtype == year %}
              {% include publication-card.html publication=pub %}
            {% endif %}
          {% endfor %}
        </div>
      </section>
    {% endfor %}
  </div>
</div>

<script src="{{ base_path }}/assets/js/publications.js"></script>
