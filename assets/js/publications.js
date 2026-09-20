(function () {
  var browser = document.querySelector("[data-publication-browser]");
  if (!browser) {
    return;
  }

  var cards = Array.prototype.slice.call(browser.querySelectorAll("[data-publication-card]"));
  var groups = Array.prototype.slice.call(browser.querySelectorAll("[data-publication-year-group]"));
  var search = browser.querySelector("[data-publication-search]");
  var count = browser.querySelector("[data-publication-count]");
  var empty = browser.querySelector("[data-publication-empty]");
  var earlier = browser.querySelector("[data-publication-earlier]");
  var filters = {
    topic: "all",
    venue: "all",
    year: "all"
  };

  function topicMatches(card, topic) {
    if (topic === "all") {
      return true;
    }

    return (" " + (card.getAttribute("data-topics") || "") + " ").indexOf(" " + topic + " ") !== -1;
  }

  function yearMatches(card, year) {
    if (year === "all") {
      return true;
    }

    if (year === "earlier") {
      return card.getAttribute("data-era") === "earlier";
    }

    return card.getAttribute("data-year") === year;
  }

  function updateFilterButtons(filterName, value) {
    var buttons = browser.querySelectorAll('[data-publication-filter="' + filterName + '"]');
    Array.prototype.forEach.call(buttons, function (button) {
      var active = button.getAttribute("data-value") === value;
      button.classList.toggle("is-active", active);
      button.setAttribute("aria-pressed", String(active));
    });
  }

  function updateGroups() {
    groups.forEach(function (group) {
      var visibleCards = group.querySelectorAll("[data-publication-card]:not(.is-hidden)");
      group.hidden = visibleCards.length === 0;
    });
  }

  function update() {
    var query = search ? search.value.trim().toLowerCase() : "";
    var hasActiveFilter = !!query || filters.year !== "all" || filters.venue !== "all" || filters.topic !== "all";
    var visibleCount = 0;

    cards.forEach(function (card) {
      var matchesYear = yearMatches(card, filters.year);
      var matchesVenue = filters.venue === "all" || card.getAttribute("data-venue") === filters.venue;
      var matchesTopic = topicMatches(card, filters.topic);
      var matchesSearch = !query || (card.getAttribute("data-search") || "").indexOf(query) !== -1;
      var isVisible = matchesYear && matchesVenue && matchesTopic && matchesSearch;

      card.classList.toggle("is-hidden", !isVisible);
      if (isVisible) {
        visibleCount += 1;
      }
    });

    updateGroups();

    if (earlier) {
      var visibleEarlierCards = earlier.querySelectorAll("[data-publication-card]:not(.is-hidden)");
      earlier.hidden = visibleEarlierCards.length === 0;
      earlier.open = filters.year === "earlier" || (hasActiveFilter && visibleEarlierCards.length > 0);
    }

    if (count) {
      count.textContent = visibleCount;
    }

    if (empty) {
      empty.hidden = visibleCount !== 0;
    }
  }

  browser.addEventListener("click", function (event) {
    var button = event.target.closest("[data-publication-filter]");
    if (!button || !browser.contains(button)) {
      return;
    }

    var filterName = button.getAttribute("data-publication-filter");
    var value = button.getAttribute("data-value");
    filters[filterName] = value;
    updateFilterButtons(filterName, value);
    update();
  });

  if (search) {
    search.addEventListener("input", update);
  }

  update();
})();
