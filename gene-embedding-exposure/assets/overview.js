/* The overview uses the frozen result record shared with the full leaderboard. */
(function () {
  const data = window.GENEPROV;
  const site = window.GeneProvSite;
  const board = window.GeneProvLeaderboard;
  const el = site.el;
  const facts = data.facts;
  const bins = [
    ["zero", "0"], ["1-10", "1–10"], ["11-100", "11–100"],
    ["101-1000", "101–1,000"], [">1000", ">1,000"]
  ];

  function renderProvenance(mode) {
    const share = mode === "share";
    const values = bins.map(([key]) => {
      const bin = facts.generated_by_bin[key];
      return share ? 100 * bin.generated / bin.n : bin.generated;
    });
    const step = share ? 20 : 1000;
    const limit = Math.ceil(Math.max(...values) / step) * step;
    const peak = Math.max(...values);
    const grid = el("div", {class: "plot-grid"});
    grid.append(el("span", {class: "axis-label", text: "Linked publications"}),
      el("span", {class: "axis-end", text: share ? "Share" : "Genes"}));
    bins.forEach(([key, label], i) => {
      const bin = facts.generated_by_bin[key];
      const bar = el("i", {class: values[i] === peak ? "peak" : ""});
      bar.style.width = (100 * values[i] / limit) + "%";
      grid.append(el("span", {class: "plot-bin", text: label}),
        el("span", {class: "plot-bar", "aria-hidden": "true",
          title: site.int(bin.generated) + " of " + site.int(bin.n) + " genes"}, [bar]),
        el("span", {class: "plot-value", text: share ? values[i].toFixed(1) + "%" : site.int(values[i])}));
    });
    const ticks = el("div", {class: "plot-ticks", "aria-hidden": "true"});
    for (let value = 0; value <= limit; value += step) {
      ticks.append(el("span", {text: share ? value + "%" : site.int(value)}));
    }
    grid.style.setProperty("--plot-step", (100 * step / limit) + "%");
    grid.append(ticks);
    document.getElementById("provenance-bars").replaceChildren(grid);
    document.querySelectorAll(".plot-switch button").forEach(b =>
      b.setAttribute("aria-pressed", String(b.dataset.mode === mode)));
  }

  function renderRanking(stratum) {
    const rows = board.viewRows(board.makeState({stratum})).sort((a, b) => b.idx - a.idx);
    const query = "?cohort=" + encodeURIComponent(stratum);
    const entries = rows.slice(0, 5).map((entry, i) => {
      const model = entry.r;
      const link = el("a", {class: "model", text: model.short,
        href: "leaderboard.html" + query + "#O:" + encodeURIComponent(model.tag)});
      const interval = entry.ci ? entry.ci.map(site.fmt1).join("–") : "—";
      return el("tr", {}, [
        el("td", {class: "position", text: String(i + 1)}),
        el("td", {}, [link]), el("td", {text: model.modality}),
        el("td", {class: "num", text: site.fmt1(entry.idx)}),
        el("td", {class: "interval", text: interval})
      ]);
    });
    document.getElementById("rank-rows").replaceChildren(...entries);
    const cohort = stratum === "all" ? "all genes" : "genes with 0–10 linked publications";
    document.getElementById("ranking-caption").textContent = "Open-track ranking for " + cohort;
    document.getElementById("rank-summary").textContent =
      "Showing the top five for " + cohort + ". " + rows[0].r.short + " ranks first.";
    document.getElementById("ranking-link").href = "leaderboard.html" + query;
  }

  document.getElementById("gene-count").textContent = site.int(facts.universe);
  document.getElementById("open-count").textContent = facts.n_rows_O_v1;
  document.getElementById("fixed-count").textContent = facts.n_rows_F;
  document.querySelectorAll(".plot-switch button").forEach(b =>
    b.addEventListener("click", () => renderProvenance(b.dataset.mode)));
  const select = document.getElementById("rank-cohort");
  select.addEventListener("change", () => renderRanking(select.value));
  renderProvenance("share");
  renderRanking(select.value);
})();
