(function () {
  var browser = document.querySelector("[data-news-browser]");
  if (!browser) {
    return;
  }

  var cards = Array.prototype.slice.call(browser.querySelectorAll("[data-news-item]"));
  var groups = Array.prototype.slice.call(browser.querySelectorAll("[data-news-year-group]"));
  var search = browser.querySelector("[data-news-search]");
  var count = browser.querySelector("[data-news-count]");
  var empty = browser.querySelector("[data-news-empty]");
  var filters = {
    type: "all"
  };

  function updateFilterButtons(filterName, value) {
    var buttons = browser.querySelectorAll('[data-news-filter="' + filterName + '"]');
    Array.prototype.forEach.call(buttons, function (button) {
      button.classList.toggle("is-active", button.getAttribute("data-value") === value);
    });
  }

  function updateGroups() {
    groups.forEach(function (group) {
      var visibleItems = group.querySelectorAll("[data-news-item]:not(.is-hidden)");
      group.classList.toggle("is-hidden", visibleItems.length === 0);
    });
  }

  function update() {
    var query = search ? search.value.trim().toLowerCase() : "";
    var visibleCount = 0;

    cards.forEach(function (card) {
      var matchesType = filters.type === "all" || card.getAttribute("data-news-type") === filters.type;
      var matchesSearch = !query || (card.getAttribute("data-news-search") || "").indexOf(query) !== -1;
      var isVisible = matchesType && matchesSearch;

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
      empty.classList.toggle("is-hidden", visibleCount > 0);
    }
  }

  browser.addEventListener("click", function (event) {
    var button = event.target.closest("[data-news-filter]");
    if (!button) {
      return;
    }

    var filterName = button.getAttribute("data-news-filter");
    var value = button.getAttribute("data-value");
    filters[filterName] = value;
    updateFilterButtons(filterName, value);
    update();
  });

  if (search) {
    search.addEventListener("input", update);
  }

  update();
}());
