(function () {
  var nav = document.getElementById("site-nav");
  if (!nav) {
    return;
  }

  var button = nav.querySelector("button");
  var visibleLinks = nav.querySelector(".visible-links");
  var hiddenLinks = nav.querySelector(".hidden-links");
  if (!button || !visibleLinks || !hiddenLinks) {
    return;
  }

  var mobileNavigation = window.matchMedia("(max-width: 767px)");
  var navigationItems = Array.prototype.slice.call(visibleLinks.children)
    .concat(Array.prototype.slice.call(hiddenLinks.children));
  var layoutFrame;

  function closeMenu() {
    hiddenLinks.classList.add("hidden");
    button.classList.remove("close");
    document.body.classList.remove("nav-menu-open");
  }

  function syncNavState() {
    var isOpen = !hiddenLinks.classList.contains("hidden");
    button.setAttribute("aria-expanded", isOpen ? "true" : "false");
    button.setAttribute("aria-label", isOpen ? "Close navigation menu" : "Open navigation menu");
    document.body.classList.toggle("nav-menu-open", isOpen && mobileNavigation.matches);
  }

  function layoutNavigation() {
    var availableSpace;
    var lastVisibleItem;

    closeMenu();

    navigationItems.forEach(function (item) {
      visibleLinks.appendChild(item);
    });

    if (mobileNavigation.matches) {
      navigationItems.slice(1).forEach(function (item) {
        hiddenLinks.appendChild(item);
      });
      button.classList.remove("hidden");
      syncNavState();
      return;
    }

    button.classList.add("hidden");
    availableSpace = nav.clientWidth;

    while (visibleLinks.getBoundingClientRect().width > availableSpace && visibleLinks.children.length > 1) {
      lastVisibleItem = visibleLinks.lastElementChild;
      hiddenLinks.insertBefore(lastVisibleItem, hiddenLinks.firstChild);
      button.classList.remove("hidden");
      availableSpace = nav.clientWidth - button.offsetWidth - 12;
    }

    if (hiddenLinks.children.length) {
      button.classList.remove("hidden");
    }

    syncNavState();
  }

  function queueNavigationLayout() {
    window.cancelAnimationFrame(layoutFrame);
    layoutFrame = window.requestAnimationFrame(layoutNavigation);
  }

  button.addEventListener("click", function () {
    window.setTimeout(syncNavState, 0);
  });

  document.addEventListener("keydown", function (event) {
    if (event.key !== "Escape" || hiddenLinks.classList.contains("hidden")) {
      return;
    }

    closeMenu();
    syncNavState();
    button.focus();
  });

  document.addEventListener("click", function (event) {
    if (nav.contains(event.target) || hiddenLinks.classList.contains("hidden")) {
      return;
    }

    closeMenu();
    syncNavState();
  });

  window.addEventListener("resize", queueNavigationLayout);
  layoutNavigation();
}());
