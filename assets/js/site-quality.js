(function () {
  var nav = document.getElementById("site-nav");
  if (!nav) {
    return;
  }

  var button = nav.querySelector("button");
  var hiddenLinks = nav.querySelector(".hidden-links");
  if (!button || !hiddenLinks) {
    return;
  }

  function syncNavState() {
    var isOpen = !hiddenLinks.classList.contains("hidden");
    button.setAttribute("aria-expanded", isOpen ? "true" : "false");
    button.setAttribute("aria-label", isOpen ? "Hide navigation links" : "Show more navigation links");
  }

  button.addEventListener("click", function () {
    window.setTimeout(syncNavState, 0);
  });

  document.addEventListener("keydown", function (event) {
    if (event.key !== "Escape" || hiddenLinks.classList.contains("hidden")) {
      return;
    }

    hiddenLinks.classList.add("hidden");
    button.classList.remove("close");
    syncNavState();
    button.focus();
  });

  document.addEventListener("click", function (event) {
    if (nav.contains(event.target) || hiddenLinks.classList.contains("hidden")) {
      return;
    }

    hiddenLinks.classList.add("hidden");
    button.classList.remove("close");
    syncNavState();
  });

  window.addEventListener("resize", syncNavState);
  syncNavState();
}());
