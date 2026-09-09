(function () {
  "use strict";

  var root = document.querySelector(".c311");
  if (!root) return;

  var ageInput = document.getElementById("c311-age");
  var closureInput = document.getElementById("c311-closure");

  function updateLabel() {
    var age = Number(ageInput.value);
    var closure = closureInput.value === "missing" ? null : Number(closureInput.value);
    var result;
    var explanation;
    document.getElementById("c311-age-value").textContent = age + (age === 1 ? " day" : " days");

    if (closure !== null && (closure < 0 || closure > age)) {
      result = "Exclude: invalid timeline";
      explanation = closure < 0
        ? "A closure before creation is an invalid timestamp. Investigate the record before assigning a label."
        : "This closure falls after the snapshot. The record cannot describe a closure that has not happened yet.";
    } else if (age < 14) {
      result = "Exclude: not mature";
      explanation = "The course requires at least 14 days of maturity, including the reporting buffer. Do not turn an immature record into a slow request.";
    } else if (closure === null) {
      result = "Label 1";
      explanation = "The record is mature and has no closure timestamp in the snapshot. This describes recorded closure, not proof that the problem remains unresolved.";
    } else if (closure <= 7) {
      result = "Label 0";
      explanation = closure === 7
        ? "The request is mature and closure at exactly seven days counts as within the window."
        : "The request is mature and its closure timestamp falls within seven days of creation.";
    } else {
      result = "Label 1";
      explanation = "A closure is recorded, but it occurred after the seven-day horizon. A later closure does not change this label to 0.";
    }
    document.getElementById("c311-label-result").textContent = result;
    document.getElementById("c311-label-explanation").textContent = explanation;
  }

  ageInput.addEventListener("input", updateLabel);
  closureInput.addEventListener("change", updateLabel);
  updateLabel();

  var probabilityInputs = Array.prototype.slice.call(root.querySelectorAll("[data-brier-label]"));
  function updateBrier() {
    var total = 0;
    probabilityInputs.forEach(function (input, index) {
      var p = Number(input.value);
      var y = Number(input.getAttribute("data-brier-label"));
      var loss = Math.pow(p - y, 2);
      total += loss;
      document.getElementById("c311-p" + index + "-value").textContent = p.toFixed(2);
      document.getElementById("c311-loss" + index).textContent = loss.toFixed(4);
    });
    document.getElementById("c311-brier-score").textContent = (total / probabilityInputs.length).toFixed(4);
  }
  probabilityInputs.forEach(function (input) { input.addEventListener("input", updateBrier); });
  var presets = { uncertain: [0.5, 0.5, 0.5], perfect: [0, 1, 1], wrong: [1, 0, 0], reset: [0.2, 0.6, 0.8] };
  root.querySelectorAll("[data-brier-preset]").forEach(function (button) {
    button.addEventListener("click", function () {
      var values = presets[button.getAttribute("data-brier-preset")];
      probabilityInputs.forEach(function (input, index) { input.value = values[index]; });
      updateBrier();
    });
  });
  updateBrier();

  var navLinks = Array.prototype.slice.call(root.querySelectorAll(".c311-sidebar nav a"));
  if ("IntersectionObserver" in window) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        navLinks.forEach(function (link) {
          if (link.getAttribute("href") === "#" + entry.target.id) link.setAttribute("aria-current", "location");
          else link.removeAttribute("aria-current");
        });
      });
    }, { rootMargin: "-15% 0px -60% 0px", threshold: 0 });
    root.querySelectorAll(".c311-section").forEach(function (section) { observer.observe(section); });
  }

  // Printed guides include every milestone and FAQ, then restore screen state.
  var closedForPrint = [];
  window.addEventListener("beforeprint", function () {
    closedForPrint = Array.prototype.slice.call(root.querySelectorAll("details:not([open])"));
    closedForPrint.forEach(function (item) { item.open = true; });
  });
  window.addEventListener("afterprint", function () {
    closedForPrint.forEach(function (item) { item.open = false; });
    closedForPrint = [];
  });
})();
