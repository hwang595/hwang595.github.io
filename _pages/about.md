---
permalink: /
title: ""
seo_title: "Hongyi Wang | Rutgers CS"
description: "Hongyi Wang is an Assistant Professor at Rutgers Computer Science working on efficient machine learning systems, LLM infrastructure, federated learning, and distributed optimization."
excerpt: "Hongyi Wang is an Assistant Professor at Rutgers CS working on efficient machine learning systems and LLM infrastructure."
author_profile: true
redirect_from: 
  - /about/
  - /about.html
---

{% assign home_publications = site.publications | sort: "date" | reverse %}
{% assign home_technical_reports = site.technical_reports | sort: "date" | reverse %}
{% assign home_news = site.news | sort: "date" | reverse %}
{% assign group = site.data.group %}
{% assign group_home_people = group.people | where: "show_on_home", true %}
{% assign home_publication_years = home_publications | map: "pubtype" | uniq | sort | reverse %}
{% assign home_publication_venues = home_publications | map: "venue" | uniq | sort %}

<div class="home-hero">
  <div class="home-hero__content">
    <p class="home-hero__eyebrow">Efficient ML Systems and LLM Infrastructure</p>
    <h1 class="home-hero__title">Building scalable, practical, and trustworthy machine learning systems.</h1>
    <p class="home-hero__subtitle">
      I am an Assistant Professor in the
      <a href="https://www.cs.rutgers.edu/">Department of Computer Science at Rutgers University</a>.
      My research focuses on scalable and efficient machine learning algorithms and systems, with a current emphasis on LLMs.
    </p>
    <div class="home-hero__actions">
      <a class="btn btn--large" href="#selected-publications">Selected Papers</a>
      <a class="btn btn--inverse btn--large" href="/group/">Research Group</a>
      <a class="btn btn--inverse btn--large" href="/cv/hwang_cv.pdf">CV</a>
    </div>
    <div class="home-hero__chips">
      <span class="home-chip">Rutgers CS</span>
      <span class="home-chip">Distributed ML</span>
      <span class="home-chip">LLM Systems</span>
      <span class="home-chip">Federated Learning</span>
    </div>
  </div>
  <div class="home-hero__stats" aria-label="Research snapshot">
    <a class="home-stat" href="/publications/">
      <strong>{{ home_publications | size }}</strong>
      <span>publications</span>
    </a>
    <a class="home-stat" href="/publications/">
      <strong>{{ home_publication_venues | size }}</strong>
      <span>venues</span>
    </a>
    <a class="home-stat" href="/publications/">
      <strong>{{ home_publication_years | size }}</strong>
      <span>years</span>
    </a>
  </div>
</div>

<div class="home-highlights">
  <div class="home-highlight">
    <h3>Background</h3>
    <p>
      I was a Senior Project Scientist at the
      <a href="https://www.ml.cmu.edu/">Machine Learning Department at CMU</a>,
      working with <a href="http://www.cs.cmu.edu/~epxing/">Eric Xing</a>.
      I obtained my PhD in Computer Science from
      <a href="https://www.cs.wisc.edu/">UW-Madison</a>, advised by
      <a href="http://papail.io/">Dimitris Papailiopoulos</a>.
    </p>
  </div>
  <div class="home-highlight">
    <h3>Research Direction</h3>
    <p>
      I study efficient training and serving of large-scale machine learning models,
      especially large language models under real system constraints.
    </p>
  </div>
</div>

<section class="home-section home-section--focus" id="research-focus">
  <div class="home-section__header">
    <p class="home-section__eyebrow">Research focus</p>
    <h2>Systems for Useful ML</h2>
  </div>
  <div class="focus-grid">
    <article class="focus-card">
      <span>01</span>
      <h3>LLM infrastructure</h3>
      <p>Training, serving, evaluation, and transparency for large models under real system constraints.</p>
    </article>
    <article class="focus-card">
      <span>02</span>
      <h3>Federated and private ML</h3>
      <p>Algorithms and systems that let models learn across distributed, sensitive, and heterogeneous data.</p>
    </article>
    <article class="focus-card">
      <span>03</span>
      <h3>Efficient optimization</h3>
      <p>Compression, low-rank methods, model fusion, and communication-efficient distributed training.</p>
    </article>
  </div>
</section>

<section class="home-section" id="selected-publications">
  <div class="home-section__header">
    <p class="home-section__eyebrow">Selected work</p>
    <h2>Selected Publications</h2>
    <a href="/publications/">Full publication list</a>
  </div>
  <div class="selected-work">
    {% for featured_slug in site.data.featured_publications %}
      {% for publication in site.publications %}
        {% assign publication_slug = publication.path | split: "/" | last | replace: ".md", "" %}
        {% if publication_slug == featured_slug %}
          {% include publication-card.html publication=publication featured=true %}
        {% endif %}
      {% endfor %}
      {% for report in home_technical_reports %}
        {% assign report_slug = report.path | split: "/" | last | replace: ".md", "" %}
        {% if report_slug == featured_slug %}
          {% include publication-card.html publication=report featured=true %}
        {% endif %}
      {% endfor %}
    {% endfor %}
  </div>
</section>

<section class="home-section" id="news">
  <div class="home-section__header">
    <p class="home-section__eyebrow">Recent notes</p>
    <h2>News</h2>
    <a href="/news/">All updates</a>
  </div>
  <div class="home-timeline">
    {% for item in home_news limit:4 %}
      {% include news-item.html item=item compact=true %}
    {% endfor %}
  </div>
</section>

<section class="home-section" id="research-group">
  <div class="home-section__header">
    <p class="home-section__eyebrow">People</p>
    <h2>RAISL Group</h2>
    <a href="/group/">Full group page</a>
  </div>
  <div class="group-preview">
    <img src="{{ group.identity.logo }}" alt="{{ group.identity.name }} logo">
    <div>
      <strong>{{ group.identity.label }}</strong>
      <p>{{ group.identity.tagline }}</p>
    </div>
  </div>
  <div class="people-grid">
    {% for person in group_home_people %}
      {% if person.url %}
        <a class="person-card" href="{{ person.url }}"><strong>{{ person.name }}</strong><span>{{ person.role }}</span></a>
      {% else %}
        <div class="person-card"><strong>{{ person.name }}</strong><span>{{ person.role }}</span></div>
      {% endif %}
    {% endfor %}
  </div>
</section>

<section class="home-section" id="teaching">
  <div class="home-section__header">
    <p class="home-section__eyebrow">Courses</p>
    <h2>Teaching</h2>
  </div>
  <div class="teaching-list">
    <div class="teaching-item"><span>Spring 2026</span><strong>CS 439, Intro to Data Science</strong></div>
    <a class="teaching-item" href="https://hwang595.github.io/RU-CS-671-Fall2025/"><span>Fall 2025</span><strong>RU CS 671, Recent Advances in Large Language Models</strong></a>
  </div>
</section>

<section class="home-section" id="service">
  <div class="home-section__header">
    <p class="home-section__eyebrow">Community</p>
    <h2>Services</h2>
  </div>
  <div class="service-panel">
    <p><strong>Area Chair:</strong> NeurIPS 2026, MLSys 2025, CPAL 2026</p>
    <p><strong>PC Member:</strong> DAC 2024, EuroSys 2024, SOSP 2023 (light PC), MLSys 2023-2026, SIGKDD 2022, AAAI 2021-2022</p>
    <p><strong>Reviewer (Journals):</strong> JMLR, TMLR, IEEE TNNLS, IEEE IoT-J, IEEE/ACM Transactions on Networking</p>
    <p><strong>Reviewer (Conferences):</strong> SC 2026, COLM 2026, ICML 2019-2026, NeurIPS 2019-2025, CVPR 2021-2023, ICCV 2021-2022, ICLR 2021-2025, AAAI 2021-2024, SIGKDD 2022-2023</p>
  </div>
</section>
