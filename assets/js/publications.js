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
      earlier.open = filters.year === "earlier" || (hasActiveFilter && visibleEarlierCards.length > 0);
    }

    if (count) {
      count.textContent = visibleCount;
    }

    if (empty) {
      empty.hidden = visibleCount !== 0;
    }
  }

  function copyText(text) {
    return new Promise(function (resolve, reject) {
      var textarea = document.createElement("textarea");
      textarea.value = text;
      textarea.setAttribute("readonly", "");
      textarea.style.position = "fixed";
      textarea.style.top = "-9999px";
      document.body.appendChild(textarea);
      textarea.focus();
      textarea.select();

      try {
        if (document.execCommand("copy")) {
          resolve();
        } else {
          reject(new Error("Copy command was not accepted."));
        }
      } catch (error) {
        reject(error);
      } finally {
        document.body.removeChild(textarea);
      }
    });
  }

  function copyBibtex(text) {
    return copyText(text).catch(function () {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        return navigator.clipboard.writeText(text);
      }

      throw new Error("No clipboard method available.");
    });
  }

  function setCopyState(button, label) {
    var labelNode = button.querySelector(".publication-link__label");
    var defaultLabel = button.getAttribute("data-copy-default");

    if (!defaultLabel) {
      defaultLabel = labelNode ? labelNode.textContent : button.textContent;
      button.setAttribute("data-copy-default", defaultLabel);
    }

    if (labelNode) {
      labelNode.textContent = label;
    } else {
      button.textContent = label;
    }

    window.setTimeout(function () {
      if (labelNode) {
        labelNode.textContent = defaultLabel;
      } else {
        button.textContent = defaultLabel;
      }
    }, 1800);
  }

  function findBibtexCode(button) {
    var card = button.closest(".publication-card");
    if (!card) {
      return null;
    }

    return card.querySelector("[data-bibtex-code]");
  }

  function selectBibtex(code) {
    var details = code.closest(".publication-card__details");
    var selection = window.getSelection();
    var range = document.createRange();

    if (details) {
      details.open = true;
    }

    range.selectNodeContents(code);
    selection.removeAllRanges();
    selection.addRange(range);
  }

  browser.addEventListener("click", function (event) {
    var copyButton = event.target.closest("[data-copy-bibtex]");
    if (copyButton && browser.contains(copyButton)) {
      var code = findBibtexCode(copyButton);
      if (!code) {
        return;
      }

      copyBibtex(code.textContent).then(function () {
        setCopyState(copyButton, "Copied");
      }).catch(function () {
        selectBibtex(code);
        setCopyState(copyButton, "Selected");
      });
      return;
    }

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
