---
permalink: /research/
title: ""
seo_title: "Research Themes | Hongyi Wang"
description: "Selected projects and research themes from Hongyi Wang and RAISL, covering LLM infrastructure, efficient ML systems, federated learning, trustworthy evaluation, and scientific foundation models."
excerpt: "Selected projects and research themes from Hongyi Wang and RAISL."
author_profile: false
og_image: "social-card.png"
og_image_alt: "RAISL selected projects and research themes"
---

{% include base_path %}
{% assign research = site.data.research_themes %}

<div class="research-page" data-publication-browser>
  <section class="research-hero">
    <div class="research-hero__copy">
      <p class="research-eyebrow">{{ research.hero.eyebrow }}</p>
      <h1>{{ research.hero.title }}</h1>
      <p class="research-hero__lead">{{ research.hero.description }}</p>
      <div class="research-hero__actions">
        <a class="btn btn--large" href="#selected-projects">Selected Projects</a>
        <a class="btn btn--inverse btn--large" href="#themes">Research Themes</a>
        <a class="btn btn--inverse btn--large" href="/publications/">All Publications</a>
      </div>
    </div>
    <div class="research-hero__summary" aria-label="Research theme snapshot">
      <span><strong>{{ research.themes | size }}</strong> themes</span>
      <span><strong>{{ research.selected_projects | size }}</strong> selected projects</span>
      <span><strong>{{ site.technical_reports | size }}</strong> technical reports</span>
    </div>
  </section>

  <nav class="research-theme-nav" aria-label="Research theme navigation">
    {% for theme in research.themes %}
      <a href="#{{ theme.id }}">
        <strong>{{ theme.title }}</strong>
        <span>{{ theme.tags | join: " / " }}</span>
      </a>
    {% endfor %}
  </nav>

  <section class="research-section" id="selected-projects">
    <div class="research-section__header">
      <p class="research-eyebrow">Selected projects</p>
      <h2>Project-Level Entry Points</h2>
      <p>These projects are good starting points for understanding the group&apos;s research trajectory.</p>
    </div>
    <div class="research-project-grid">
      {% for project in research.selected_projects %}
        <a class="research-project-card" href="#{{ project.theme_id }}">
          <span>{{ project.theme }}</span>
          <h3>{{ project.title }}</h3>
          <p>{{ project.summary }}</p>
          <small>See related theme</small>
        </a>
      {% endfor %}
    </div>
  </section>

  <section class="research-section" id="themes">
    <div class="research-section__header">
      <p class="research-eyebrow">Research map</p>
      <h2>Themes and Representative Work</h2>
      <p>Each theme highlights current questions and representative papers or technical reports.</p>
    </div>

    <div class="research-theme-stack">
      {% for theme in research.themes %}
        <article class="research-theme" id="{{ theme.id }}">
          <div class="research-theme__overview">
            <p class="research-theme__index">0{{ forloop.index }}</p>
            <h3>{{ theme.title }}</h3>
            <p>{{ theme.summary }}</p>

            <div class="research-tag-list">
              {% for tag in theme.tags %}
                <span>{{ tag }}</span>
              {% endfor %}
            </div>

            <div class="research-question-panel">
              <h4>Questions we ask</h4>
              <ul>
                {% for question in theme.questions %}
                  <li>{{ question }}</li>
                {% endfor %}
              </ul>
            </div>
          </div>

          <div class="research-theme__work">
            <h4>Representative work</h4>
            <div class="research-paper-grid">
              {% for slug in theme.project_slugs %}
                {% include publication-by-slug.html slug=slug filterable=false %}
              {% endfor %}
            </div>
          </div>
        </article>
      {% endfor %}
    </div>
  </section>
</div>

<script src="{{ '/assets/js/publications.js' | relative_url }}"></script>

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "CollectionPage",
  "@id": {{ site.url | append: site.baseurl | append: "/research/#collection" | jsonify }},
  "name": "Research Themes",
  "url": {{ site.url | append: site.baseurl | append: "/research/" | jsonify }},
  "description": {{ page.description | jsonify }},
  "isPartOf": {
    "@id": {{ site.url | append: site.baseurl | append: "/#website" | jsonify }}
  },
  "about": [
    {% for theme in research.themes %}
      {
        "@type": "Thing",
        "name": {{ theme.title | jsonify }},
        "description": {{ theme.summary | jsonify }}
      }{% unless forloop.last %},{% endunless %}
    {% endfor %}
  ]
}
</script>
