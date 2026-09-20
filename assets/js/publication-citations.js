(function () {
  function copyFallback(text) {
    return new Promise(function (resolve, reject) {
      var focused = document.activeElement;
      var textarea = document.createElement("textarea");
      textarea.value = text;
      textarea.setAttribute("readonly", "");
      textarea.style.position = "fixed";
      textarea.style.top = "-9999px";
      document.body.appendChild(textarea);
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
        if (focused) {
          focused.focus({ preventScroll: true });
        }
      }
    });
  }

  function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text).catch(function () {
        return copyFallback(text);
      });
    }
    return copyFallback(text);
  }

  document.addEventListener("click", function (event) {
    var button = event.target.closest("[data-copy-bibtex]");
    if (!button || button.disabled) {
      return;
    }
    var card = button.closest(".publication-card");
    var code = card && card.querySelector("[data-bibtex-code]");
    if (!code) {
      return;
    }

    var label = button.querySelector(".publication-link__label") || button;
    var defaultLabel = label.textContent;
    button.disabled = true;

    copyText(code.textContent).then(function () {
      label.textContent = "Copied";
    }).catch(function () {
      var details = code.closest("details");
      if (details) {
        details.open = true;
      }
      var selection = window.getSelection();
      var range = document.createRange();
      range.selectNodeContents(code);
      selection.removeAllRanges();
      selection.addRange(range);
      label.textContent = "Selected; copy manually";
    }).then(function () {
      window.setTimeout(function () {
        label.textContent = defaultLabel;
        button.disabled = false;
      }, 1800);
    });
  });
}());
