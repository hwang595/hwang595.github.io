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

<h2>2021</h2>
{% for post in site.publications reversed %}
  {% if post.pubtype == '2021' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}

<h2>2020</h2>
{% for post in site.publications reversed %}
  {% if post.pubtype == '2020' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}

<h2>2019</h2>
{% for post in site.publications reversed %}
  {% if post.pubtype == '2019' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}


<h2>2018</h2>
{% for post in site.publications reversed %}
  {% if post.pubtype == '2018' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}


<h2>2017</h2>
{% for post in site.publications reversed %}
  {% if post.pubtype == '2017' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}