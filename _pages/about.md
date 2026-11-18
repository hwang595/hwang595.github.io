---
permalink: /
title: ""
seo_title: "Hongyi Wang | Rutgers CS"
description: "Hongyi Wang is an Assistant Professor at Rutgers Computer Science working on efficient machine learning systems, LLM infrastructure, MoE/RL post-training, federated learning, and distributed optimization."
excerpt: "Hongyi Wang is an Assistant Professor at Rutgers CS working on efficient machine learning systems, LLM infrastructure, and MoE/RL post-training."
author_profile: true
redirect_from: 
  - /about/
  - /about.html
---

{% assign home_technical_reports = site.technical_reports | sort: "date" | reverse %}
{% assign home_news = site.news | sort: "date" | reverse %}
{% assign group = site.data.group %}
{% assign group_home_people = group.people | where: "show_on_home", true %}
<section class="home-intro" aria-labelledby="intro-heading">
  <h1 id="intro-heading">Efficient machine learning systems</h1>
  <p>
    I'm an assistant professor of <a href="https://www.cs.rutgers.edu/">computer science at Rutgers University</a>.
    My group studies how to train and serve large language models efficiently and evaluate them reliably.
    We currently focus on mixture-of-experts models and reinforcement learning for post-training.
  </p>
  <nav class="home-intro__links" aria-label="Profile links">
    <a href="#selected-publications">Selected papers</a>
    <a href="/group/">Research group</a>
    <a href="/cv/hwang_cv.pdf">CV</a>
  </nav>
  <details class="home-background">
    <summary>Academic background</summary>
    <p>
      Previously, I was a Senior Project Scientist in the
      <a href="https://www.ml.cmu.edu/">Machine Learning Department at CMU</a>, working with
      <a href="http://www.cs.cmu.edu/~epxing/">Eric Xing</a>. I earned my PhD in Computer Science from
      <a href="https://www.cs.wisc.edu/">UW-Madison</a>, advised by
      <a href="http://papail.io/">Dimitris Papailiopoulos</a>.
    </p>
  </details>
</section>

<section class="home-section" id="research-focus">
  {% include home-section-heading.html title="Research focus" url="/research/" link_text="Research themes" %}
  <div class="focus-grid">
    <article class="focus-card">
      <h3>LLM infrastructure</h3>
      <p>Training, serving, and evaluating large models under real compute and memory constraints.</p>
    </article>
    <article class="focus-card">
      <h3>Federated and private ML</h3>
      <p>Learning across institutions when data is sensitive, distributed, or unevenly sampled.</p>
    </article>
    <article class="focus-card">
      <h3>Efficient optimization</h3>
      <p>Reducing computation and communication through compression, low-rank methods, and model fusion.</p>
    </article>
  </div>
</section>

<section class="home-section" id="selected-publications">
  {% include home-section-heading.html title="Selected publications" url="/publications/" link_text="Full publication list" %}
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
  {% include home-section-heading.html title="News" url="/news/" link_text="All updates" %}
  <div class="home-timeline">
    {% for item in home_news limit:4 %}
      {% include news-item.html item=item compact=true %}
    {% endfor %}
  </div>
</section>

<section class="home-section" id="research-group">
  {% include home-section-heading.html title="RAISL group" url="/group/" link_text="Full group page" %}
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
  {% include home-section-heading.html title="Teaching" %}
  {% include teaching-list.html %}
</section>

<section class="home-section" id="service">
  {% include home-section-heading.html title="Academic service" %}
  <div class="service-panel">
    <p><strong>Area Chair:</strong> ICML 2027 (invited), ICLR 2027, NeurIPS 2026, ACL ARR 2026 May, CPAL 2026, MLSys 2025</p>
    <p><strong>PC Member:</strong> DAC 2024, EuroSys 2024, SOSP 2023 (light PC), MLSys 2023-2026, SIGKDD 2022, AAAI 2021-2022</p>
    <p><strong>Reviewer (Journals):</strong> JMLR, TMLR, IEEE TNNLS, IEEE IoT-J, IEEE/ACM Transactions on Networking</p>
    <p><strong>Reviewer (Conferences):</strong> SC 2026, COLM 2026, ICML 2019-2026, NeurIPS 2019-2025, CVPR 2021-2023, ICCV 2021-2022, ICLR 2021-2025, AAAI 2021-2024, SIGKDD 2022-2023</p>
  </div>
</section>
