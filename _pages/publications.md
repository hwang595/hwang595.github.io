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

<h3 style="margin: 0; line-height:50px;">2023</h3>
{% for post in site.publications reversed %}
  {% if post.pubtype == '2023' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}

<h3 style="margin: 0; line-height:50px;">2022</h3>
{% for post in site.publications reversed %}
  {% if post.pubtype == '2022' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}

<h3 style="margin: 0; line-height:50px;">2021</h3>
{% for post in site.publications reversed %}
  {% if post.pubtype == '2021' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}

<h3 style="margin: 0; line-height:50px;">2020</h3>
{% for post in site.publications reversed %}
  {% if post.pubtype == '2020' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}

<h3 style="margin: 0; line-height:50px;">2019</h3>
{% for post in site.publications reversed %}
  {% if post.pubtype == '2019' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}


<h3 style="margin: 0; line-height:50px;">2018</h3>
{% for post in site.publications reversed %}
  {% if post.pubtype == '2018' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}


<h3 style="margin: 0; line-height:50px;">2017</h3>
{% for post in site.publications reversed %}
  {% if post.pubtype == '2017' %}
      {% include archive-single.html %}
  {% endif %}
{% endfor %}