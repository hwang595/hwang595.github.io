---
permalink: /group/
title: ""
seo_title: "RAISL Group | Rutgers CS"
description: "RAISL is Hongyi Wang's research group at Rutgers Computer Science, working on efficient ML systems, LLM infrastructure, federated learning, optimization, and trustworthy machine learning."
excerpt: "RAISL is Hongyi Wang's research group at Rutgers Computer Science."
author_profile: false
og_image: "social-card.png"
og_image_alt: "RAISL group at Rutgers Computer Science"
---

{% include base_path %}
{% assign group = site.data.group %}
{% assign home_people = group.people | where: "show_on_home", true %}

<div class="group-page">
  <section class="group-hero">
    <div class="group-hero__copy">
      <p class="group-eyebrow">{{ group.identity.label }}</p>
      <h1>{{ group.identity.tagline }}</h1>
      <p class="group-hero__lead">{{ group.identity.description }}</p>
      <div class="group-hero__actions">
        <a class="btn btn--large" href="#join">Join RAISL</a>
        <a class="btn btn--inverse btn--large" href="#people">People</a>
        <a class="btn btn--inverse btn--large" href="/publications/">Publications</a>
      </div>
    </div>

    <div class="group-identity" aria-label="RAISL identity">
      <img src="{{ base_path }}{{ group.identity.logo }}" alt="{{ group.identity.name }} logo">
      <div>
        <strong>{{ group.identity.name }}</strong>
        <span>{{ group.identity.institution }}</span>
        <span>{{ group.identity.office }}</span>
        <a href="mailto:{{ group.identity.email }}?subject={{ group.joining.email_subject | uri_escape }}">{{ group.identity.email }}</a>
      </div>
    </div>
  </section>

  <div class="group-snapshot" aria-label="RAISL snapshot">
    <div class="group-stat">
      <strong>{{ home_people | size }}</strong>
      <span>student researchers</span>
    </div>
    <div class="group-stat">
      <strong>{{ group.themes | size }}</strong>
      <span>research themes</span>
    </div>
    <div class="group-stat">
      <strong>{{ site.publications | size }}</strong>
      <span>publications</span>
    </div>
  </div>

  <section class="group-section" id="themes">
    <div class="group-section__header">
      <p class="group-eyebrow">Research themes</p>
      <h2>What We Build</h2>
      <p>Our work sits at the boundary of algorithms, systems, and practical deployment.</p>
    </div>

    <div class="group-theme-grid">
      {% for theme in group.themes %}
        <article class="group-theme-card">
          <h3>{{ theme.title }}</h3>
          <p>{{ theme.summary }}</p>
          <div class="group-tag-list">
            {% for tag in theme.tags %}
              <span>{{ tag }}</span>
            {% endfor %}
          </div>
        </article>
      {% endfor %}
    </div>
  </section>

  <section class="group-section" id="people">
    <div class="group-section__header">
      <p class="group-eyebrow">People</p>
      <h2>RAISL Members</h2>
      <p>Students and collaborators working on efficient, scalable, and trustworthy ML systems.</p>
    </div>

    <div class="group-people">
      {% for category in group.people_categories %}
        {% assign members = group.people | where: "group", category.id %}
        {% if members.size > 0 %}
          <section class="group-people-block">
            <h3>{{ category.label }}</h3>
            <div class="group-member-grid">
              {% for person in members %}
                {% if person.url %}
                  <a class="group-person-card" href="{{ person.url }}">
                {% else %}
                  <div class="group-person-card">
                {% endif %}
                    <strong>{{ person.name }}</strong>
                    <span>{{ person.role }}</span>
                    {% if person.interests %}
                      <div class="group-tag-list">
                        {% for interest in person.interests %}
                          <small>{{ interest }}</small>
                        {% endfor %}
                      </div>
                    {% endif %}
                {% if person.url %}
                  </a>
                {% else %}
                  </div>
                {% endif %}
              {% endfor %}
            </div>
          </section>
        {% endif %}
      {% endfor %}
    </div>
  </section>

  <section class="group-section" id="join">
    <div class="group-section__header">
      <p class="group-eyebrow">Join us</p>
      <h2>Working With RAISL</h2>
      <p>{{ group.joining.intro }}</p>
    </div>

    <div class="group-join-grid">
      {% for path in group.joining.paths %}
        <article class="group-join-card">
          <h3>{{ path.title }}</h3>
          <p>{{ path.text }}</p>
        </article>
      {% endfor %}
    </div>

    <div class="group-contact-strip">
      <div>
        <strong>Contact</strong>
        <span>Use a concise subject, include your CV or resume, and mention the research area that most interests you.</span>
      </div>
      <a class="btn" href="mailto:{{ group.identity.email }}?subject={{ group.joining.email_subject | uri_escape }}">Email RAISL</a>
    </div>
  </section>
</div>

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "ResearchOrganization",
  "@id": {{ site.url | append: site.baseurl | append: "/group/#organization" | jsonify }},
  "name": {{ group.identity.name | jsonify }},
  "url": {{ site.url | append: site.baseurl | append: "/group/" | jsonify }},
  "logo": {{ site.url | append: site.baseurl | append: group.identity.logo | jsonify }},
  "description": {{ group.identity.description | jsonify }},
  "parentOrganization": {
    "@type": "CollegeOrUniversity",
    "name": "Rutgers University"
  },
  "email": {{ group.identity.email | prepend: "mailto:" | jsonify }},
  "member": [
    {% for person in group.people %}
      {
        "@type": "Person",
        "name": {{ person.name | jsonify }},
        "roleName": {{ person.role | jsonify }}{% if person.url %},
        "url": {{ person.url | absolute_url | jsonify }}{% endif %}
      }{% unless forloop.last %},{% endunless %}
    {% endfor %}
  ]
}
</script>
