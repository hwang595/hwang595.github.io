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

  function updateFilterButtons(filterName, value) {
    var buttons = browser.querySelectorAll('[data-publication-filter="' + filterName + '"]');
    Array.prototype.forEach.call(buttons, function (button) {
      button.classList.toggle("is-active", button.getAttribute("data-value") === value);
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
    var visibleCount = 0;

    cards.forEach(function (card) {
      var matchesYear = filters.year === "all" || card.getAttribute("data-year") === filters.year;
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
