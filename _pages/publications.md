---
layout: archive
title: "Publications"
permalink: /publications/
author_profile: true
---

{% if site.author.googlescholar %}
  My Google Scholar page can be found <u><a href="{{site.author.googlescholar}}">here</a>.</u>
{% endif %}

{% include base_path %}

<h2>Pre-prints</h2>
{% for post in site.publications reversed %}
  {% if post.pubtype == 'preprints' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}

<h2>Conference Papers</h2>
{% for post in site.publications reversed %}
  {% if post.pubtype == 'conference' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}


