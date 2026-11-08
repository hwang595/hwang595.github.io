// GeneProv website: shared behaviour (theme, navigation, small helpers). No dependencies.
(function () {
  const root = document.documentElement;
  function stored() { try { return localStorage.getItem("geneprov-theme"); } catch (e) { return null; } }
  function apply(t) { if (t === "dark" || t === "light") root.setAttribute("data-theme", t); else root.removeAttribute("data-theme"); }
  apply(stored());
  function current() { const t = root.getAttribute("data-theme"); if (t) return t; return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"; }
  window.GeneProvSite = {
    toggleTheme() { const next = current() === "dark" ? "light" : "dark"; apply(next); try { localStorage.setItem("geneprov-theme", next); } catch (e) {} document.dispatchEvent(new CustomEvent("geneprov:theme", { detail: next })); },
    fmt1(v) { return v == null ? "–" : (Math.round(v * 10) / 10).toFixed(1); },
    fmt3(v) { return v == null ? "–" : Number(v).toFixed(3); },
    pct(v, d) { return v == null ? "–" : (100 * v).toFixed(d == null ? 0 : d) + "%"; },
    int(v) { return v == null ? "–" : Number(v).toLocaleString("en-US"); },
    bytes(n) { return n >= 1048576 ? (n / 1048576).toFixed(1) + " MB" : n >= 1024 ? Math.round(n / 1024) + " KB" : n + " B"; },
    el(tag, attrs, children) { const e = document.createElement(tag); if (attrs) for (const k in attrs) { if (k === "class") e.className = attrs[k]; else if (k === "text") e.textContent = attrs[k]; else if (k.startsWith("on")) e.addEventListener(k.slice(2), attrs[k]); else if (attrs[k] != null) e.setAttribute(k, attrs[k]); }
      (children || []).forEach(c => { if (c == null) return; e.appendChild(typeof c === "string" ? document.createTextNode(c) : c); }); return e; },
  };
  document.addEventListener("DOMContentLoaded", () => {
    // mark the current page in the navigation
    const here = location.pathname.split("/").pop() || "index.html";
    document.querySelectorAll("nav.main a").forEach(a => { const h = a.getAttribute("href"); if (h === here || (here === "index.html" && h === "./")) a.setAttribute("aria-current", "page"); });
    const b = document.querySelector(".theme-btn"); if (b) b.addEventListener("click", window.GeneProvSite.toggleTheme);
    // copy buttons for code blocks that opt in
    document.querySelectorAll("[data-copy]").forEach(btn => btn.addEventListener("click", () => {
      const src = document.getElementById(btn.getAttribute("data-copy")); if (!src) return;
      const txt = src.textContent; const done = () => { const old = btn.textContent; btn.textContent = "Copied"; setTimeout(() => { btn.textContent = old; }, 1400); };
      const failed = () => { btn.textContent = "Copy unavailable — select the text above"; };
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(txt).then(done, failed); else failed();
    }));
  });
})();
