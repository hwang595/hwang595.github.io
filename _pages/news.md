---
permalink: /news/
title: "News"
excerpt: "Recent updates from Hongyi Wang's research group."
author_profile: true
---

{% assign news_items = site.news | sort: "date" | reverse %}
{% assign news_types = news_items | map: "type" | uniq | sort %}

<div class="news-browser" data-news-browser>
  <div class="news-browser__intro">
    <div>
      <h1>News</h1>
      <p class="news-intro">
        Research updates, awards, teaching notes, and group milestones.
      </p>
    </div>
    <div class="news-browser__stats" aria-label="News snapshot">
      <span><strong>{{ news_items | size }}</strong> updates</span>
      <span><strong>{{ news_types | size }}</strong> categories</span>
    </div>
  </div>

  <div class="news-controls">
    <label class="news-search">
      Search
      <input type="search" placeholder="Title, topic, category, or year" data-news-search>
    </label>

    <div class="news-filter-group" data-news-filter-group="type">
      <span>Category</span>
      <button type="button" class="is-active" data-news-filter="type" data-value="all">All</button>
      {% for type in news_types %}
        <button type="button" data-news-filter="type" data-value="{{ type | slugify }}">{{ type }}</button>
      {% endfor %}
    </div>
  </div>

  <p class="news-result-count">Showing <span data-news-count>{{ news_items | size }}</span> updates</p>
  <p class="news-no-results is-hidden" data-news-empty>No updates match the current filters.</p>

  <div class="news-timeline">
    {% assign current_year = "" %}
    {% for item in news_items %}
      {% assign item_year = item.date | date: "%Y" %}
      {% if item_year != current_year %}
        {% unless forloop.first %}
            </div>
          </section>
        {% endunless %}
        <section class="news-year-group" data-news-year-group>
          <h2 class="news-year">{{ item_year }}</h2>
          <div class="news-year-group__items">
        {% assign current_year = item_year %}
      {% endif %}

      {% include news-item.html item=item %}

      {% if forloop.last %}
          </div>
        </section>
      {% endif %}
    {% endfor %}
  </div>
</div>

<script src="{{ base_path }}/assets/js/news.js"></script>
