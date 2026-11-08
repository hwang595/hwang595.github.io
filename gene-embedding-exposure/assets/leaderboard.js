// GeneProv leaderboard: ranked bar chart, table view, row details. Renders window.GENEPROV (data/leaderboard.js). No dependencies.
window.GeneProvLeaderboard = (function () {
  const S = window.GeneProvSite, D = window.GENEPROV;
  const CLS = {
    bio:     { fill: "var(--aqua)",   label: "Sequence or expression model; no text embedded, none in training" },
    biotext: { fill: "var(--aqua)",   hatch: true, label: "Text in training (text-aligned protein encoder) or declared mixture" },
    gen:     { fill: "var(--orange)", label: "Text containing GO-generated summaries" },
    clean:   { fill: "var(--blue)",   label: "Text without generated summaries (summary-filtered, LLM-written, symbol-only or UniProt text)" },
    annot:   { fill: "var(--annot)",  label: "Annotation vector (reference)" },
  };
  const W1 = { "0": 0, "1/4": 0.25, "1/3": 1 / 3, "1/2": 0.5 };
  const LABELS = { depmap_essential: "DepMap common essential", hpa_loc_nucleoplasm: "HPA location: nucleoplasm", hpa_loc_cytosol: "HPA location: cytosol", hpa_loc_plasma_membrane: "HPA location: plasma membrane", hpa_loc_vesicles: "HPA location: vesicles", hpa_loc_mitochondria: "HPA location: mitochondria", hpa_loc_golgi_apparatus: "HPA location: Golgi apparatus", gtex_tissue_specific: "GTEx tissue-specific", hpa_tissue_enriched: "HPA tissue-enriched", clingen_hi: "ClinGen haploinsufficiency", constraint: "gnomAD constraint (LOEUF < 0.6)" };
  const el = S.el, f1 = S.fmt1, f3 = S.fmt3;

  function indexAt(p, w) { if (w === "1/3" || p.index == null) return p.index; const k = p.skills; if (k.T1 == null || k.T2 == null || k.T4 == null) return null; const a = W1[w]; return a * k.T1 + (1 - a) / 2 * (k.T2 + k.T4); }
  function scoreLabel(w) { return w === "1/3" ? "GeneProv Index" : "Weighted score (T1 weight " + w + ")"; }
  function viewRows(st) {
    return D.rows.filter(r => r.track === st.track && !r.t3_only && (st.version === "v1.1" || r.version === "v1"))
      .map(r => { const p = r.probes[st.probe][st.stratum]; return { r, p, idx: indexAt(p, st.w1),
        ci: st.w1 === "1/3" ? p.ci : null, rank: st.w1 === "1/3" ? p.rank : null,
        rank_ci: st.w1 === "1/3" ? p.rank_ci : null }; }).filter(x => x.idx != null);
  }
  function findRow(track, tag) { return D.rows.find(r => r.track === track && r.tag === tag); }
  function makeState(o) { return Object.assign({ track: "O", stratum: "0-10", probe: "linear", version: "v1", intervals: "gene", w1: "1/3", sort: { key: "index", dir: "desc" }, selected: null }, o || {}); }

  function mount(container, opts) {
    opts = opts || {}; const st = makeState(opts.state); const compact = !!opts.compact; const uid = "gp" + Math.random().toString(36).slice(2, 7);
    container.classList.add("leaderboard");
    const tipEl = el("div", { class: "tip", hidden: "" }); document.body.appendChild(tipEl);
    const parts = {};
    if (!compact) {
      parts.kpis = el("div", { class: "tiles" }); container.appendChild(parts.kpis);
      parts.controls = el("div", { class: "controls" }); container.appendChild(parts.controls);
    }
    parts.legend = el("div", { class: "legend" }); container.appendChild(parts.legend);
    parts.chart = el("div", { class: "chart-card" }); container.appendChild(parts.chart);
    if (!compact) {
      parts.note = el("p", { class: "footnote" }); container.appendChild(parts.note);
      parts.toolbar = el("div", { class: "toolbar" }); container.appendChild(parts.toolbar);
      parts.tbl = el("div", { class: "tbl-wrap" }); container.appendChild(parts.tbl);
      parts.detail = el("div", { class: "detail" }); container.appendChild(parts.detail);
      parts.family = el("div"); container.appendChild(parts.family);
      parts.t3only = el("div"); container.appendChild(parts.t3only);
    }

    function rowsNow() { return viewRows(st); }
    function sorted() { const rs = rowsNow(); rs.sort((a, b) => b.idx - a.idx); rs.forEach((x, i) => { x.pos = i + 1; }); return rs; }

    // ---- controls
    function chipGroup(label, key, options) {
      const g = el("div", { class: "group" }, [el("span", { class: "lbl", text: label })]);
      options.forEach(([v, txt, title]) => g.appendChild(el("button", { class: "chip", type: "button", "data-k": key, "data-v": v, "aria-pressed": String(st[key] === v), title: title || "", text: txt, onclick: () => { st[key] = v; st.selected = null; syncChips(); render(); } })));
      return g;
    }
    function syncChips() { container.querySelectorAll(".chip[data-k]").forEach(c => c.setAttribute("aria-pressed", String(st[c.dataset.k] === c.dataset.v))); try { localStorage.setItem("geneprov-lb", JSON.stringify({ track: st.track, stratum: st.stratum, probe: st.probe, version: st.version })); } catch (e) {} }
    if (!compact) {
      try { const v = JSON.parse(localStorage.getItem("geneprov-lb") || "null"); if (v && !opts.state) Object.assign(st, v); } catch (e) {}
      parts.controls.append(
        chipGroup("Track", "track", [["O", "Open representation", "Any representation with declared text provenance"], ["F", "Fixed text (embedders)", "Text embedders scored on one fixed, summary-filtered corpus"]]),
        chipGroup("Genes", "stratum", [["0-10", "0–10 publications", "Headline stratum: 7,120 genes with at most ten linked publications"], ["all", "All genes", "All 19,256 protein-coding genes"]]),
        chipGroup("Probe", "probe", [["linear", "Linear"], ["mlp", "MLP"]]),
        chipGroup("Rows", "version", [["v1", "v1 (frozen)"], ["v1.1", "v1 + v1.1 appended"]]),
        chipGroup("Sensitivity", "intervals", [["gene", "Frozen record"], ["family", "Add family analysis", "Separate round-14 regenerated estimates and family-clustered intervals; frozen bars stay unchanged"]]),
        chipGroup("T1 weight", "w1", [["0", "0"], ["1/4", "¼"], ["1/3", "⅓ (index)"], ["1/2", "½"]]),
      );
    }

    // ---- KPIs
    function renderKpis() {
      if (compact) return; const rs = sorted(); if (!rs.length) { parts.kpis.replaceChildren(); return; }
      const top = rs[0], bio = rs.find(x => x.r.cls === "bio"), txt = rs.find(x => x.r.cls === "gen" || x.r.cls === "clean");
      const n = D.strata[st.stratum];
      const tile = (v, k, s) => el("div", { class: "tile" }, [el("div", { class: "v", text: v }), el("div", { class: "k", text: k }), s ? el("div", { class: "s", text: s }) : null]);
      parts.kpis.replaceChildren(...[
        tile(f1(top.idx), st.w1 === "1/3" ? "Top index" : "Top weighted score", top.r.name),
        bio ? tile(f1(bio.idx), "Best model without text", bio.r.name) : null,
        txt ? tile(f1(txt.idx), st.track === "F" ? "Best embedder on corpus L" : "Best text-only row", txt.r.name) : null,
        tile(S.int(n), st.stratum === "0-10" ? "genes with 0–10 publications" : "genes in the universe", rs.length + " rows · " + (st.probe === "mlp" ? "MLP" : "linear") + " probe"),
      ].filter(Boolean));
    }
    // ---- legend
    function renderLegend() {
      const used = new Set(rowsNow().map(x => x.r.cls));
      parts.legend.replaceChildren(...Object.entries(CLS).filter(([k]) => used.has(k)).map(([k, c]) => el("span", {}, [el("i", { class: "sw", style: c.hatch ? "background:repeating-linear-gradient(135deg, var(--aqua) 0 2px, var(--aqua-ink) 2px 3px)" : "background:" + c.fill }), c.label])));
    }
    // ---- tooltip
    function showTip(x, ev) {
      const p = x.p; const rows = [];
      rows.push([scoreLabel(st.w1), f1(x.idx) + (x.ci ? " (" + f1(x.ci[0]) + "–" + f1(x.ci[1]) + ")" : "")]);
      if (x.rank != null) rows.push(["Frozen v1 rank", x.rank + (x.rank_ci ? " (" + x.rank_ci.join("–") + ")" : "")]);
      rows.push(["T1 GO recovery", f3(p.T1)]); rows.push(["T2 non-GO labels (" + (p.T2_labels || 0) + ")", f3(p.T2)]); rows.push(["T4 co-essentiality", f3(p.T4)]);
      if (p.T3 != null) rows.push(["T3 annotation holdout", f3(p.T3)]);
      if (p.S != null) rows.push(["S (summary sensitivity)", f3(p.S)]);
      tipEl.replaceChildren(el("div", { class: "t", text: x.r.name }), ...rows.map(([k, v]) => el("div", { class: "r" }, [el("span", { text: k }), el("b", { text: v })])), el("div", { class: "r" }, [el("span", { class: "dim", text: x.r.text_label })]));
      tipEl.hidden = false; moveTip(ev);
    }
    function moveTip(ev) { if (!ev) return; const w = tipEl.offsetWidth || 260, h = tipEl.offsetHeight || 120; let L = ev.clientX + 14, T = ev.clientY + 14; if (L + w > window.innerWidth - 8) L = ev.clientX - w - 14; if (T + h > window.innerHeight - 8) T = ev.clientY - h - 14; tipEl.style.left = Math.max(8, L) + "px"; tipEl.style.top = Math.max(8, T) + "px"; }
    function hideTip() { tipEl.hidden = true; }

    // ---- chart
    function renderChart() {
      let rs = sorted(); if (compact && opts.top) rs = rs.slice(0, opts.top);
      if (!rs.length) { parts.chart.replaceChildren(el("p", { class: "muted", text: "No rows for this view." })); return; }
      const W = 1000, L = 340, R = 76, rowH = 28, barH = 22, top = 26, H = top + rs.length * rowH + 40;
      const lo = Math.min(0, ...rs.map(x => x.ci ? x.ci[0] : x.idx)); const hi = Math.max(...rs.map(x => x.ci ? x.ci[1] : x.idx));
      const xmin = Math.floor(lo / 10) * 10, xmax = Math.ceil((hi + 2) / 5) * 5; const X = v => L + (v - xmin) / (xmax - xmin) * (W - L - R);
      const ns = "http://www.w3.org/2000/svg"; const svg = document.createElementNS(ns, "svg"); svg.setAttribute("viewBox", `0 0 ${W} ${H}`); svg.setAttribute("width", String(W)); svg.setAttribute("role", "img");
      svg.setAttribute("aria-label", `Ranked ${scoreLabel(st.w1)} bars, ${rs.length} representations, ${st.stratum === "0-10" ? "genes with 0 to 10 publications" : "all genes"}, ${st.probe} probe`);
      const mk = (t, a, txt) => { const e = document.createElementNS(ns, t); for (const k in a) e.setAttribute(k, a[k]); if (txt != null) e.textContent = txt; return e; };
      const defs = mk("defs", {}); const pat = mk("pattern", { id: uid + "-hatch", width: "6", height: "6", patternUnits: "userSpaceOnUse", patternTransform: "rotate(45)" });
      pat.append(mk("rect", { width: "6", height: "6", fill: "var(--aqua)" }), mk("rect", { width: "2", height: "6", fill: "var(--aqua-ink)" })); defs.appendChild(pat); svg.appendChild(defs);
      for (let t = xmin; t <= xmax; t += 10) { svg.appendChild(mk("line", { x1: X(t), y1: top - 8, x2: X(t), y2: H - 34, stroke: t === 0 ? "var(--axis)" : "var(--grid)", "stroke-width": "1" })); svg.appendChild(mk("text", { x: X(t), y: H - 18, "text-anchor": "middle", "font-size": "11", fill: "var(--muted)" }, String(t))); }
      svg.appendChild(mk("text", { x: X((xmin + xmax) / 2), y: H - 3, "text-anchor": "middle", "font-size": "11.5", fill: "var(--ink-2)" }, st.w1 === "1/3" ? "GeneProv Index: mean of T1, T2 and T4 skills (0 = chance, 100 = perfect)" : scoreLabel(st.w1) + ": w·T1 + (1−w)/2·(T2+T4), using task skills"));
      svg.appendChild(mk("text", { x: 8, y: top - 10, "font-size": "11", fill: "var(--muted)" }, "position"));
      rs.forEach((x, i) => {
        const y = top + i * rowH, v = x.idx, ci = x.ci; const c = CLS[x.r.cls] || CLS.clean;
        const g = mk("g", { class: "bar-row", tabindex: "0", role: "button", "data-tag": x.r.tag });
        g.setAttribute("aria-label", `${x.r.name}: ${scoreLabel(st.w1)} ${f1(v)}${ci ? ", 95% interval " + f1(ci[0]) + " to " + f1(ci[1]) : ""}${x.rank ? ", rank " + x.rank : ""}`);
        const rk = String(x.pos);
        const rt = mk("text", { x: 8, y: y + 16, "font-size": "12", fill: x.r.version === "v1.1" ? "var(--accent-ink)" : "var(--ink-2)", "font-weight": x.r.version === "v1.1" ? "600" : "400" }, rk);
        g.appendChild(rt);
        g.appendChild(mk("text", { x: L - 12, y: y + 16, "text-anchor": "end", "font-size": "12.5", fill: "var(--ink)" }, x.r.short));
        const x0 = X(Math.min(0, v)), x1 = X(Math.max(0, v)), w = Math.max(0, x1 - x0), r = Math.min(4, w / 2), yb = y + (rowH - barH) / 2;
        const d = v >= 0 ? `M${x0},${yb} H${x1 - r} a${r},${r} 0 0 1 ${r},${r} V${yb + barH - r} a${r},${r} 0 0 1 -${r},${r} H${x0} Z` : `M${x1},${yb} H${x0 + r} a${r},${r} 0 0 0 -${r},${r} V${yb + barH - r} a${r},${r} 0 0 0 ${r},${r} H${x1} Z`;
        g.appendChild(mk("path", { class: "bar", d, fill: c.hatch ? `url(#${uid}-hatch)` : c.fill }));
        if (ci) { const yc = y + rowH / 2; g.appendChild(mk("line", { x1: X(ci[0]), y1: yc, x2: X(ci[1]), y2: yc, stroke: "var(--ink)", "stroke-width": "1.5" })); [ci[0], ci[1]].forEach(e => g.appendChild(mk("line", { x1: X(e), y1: yc - 4, x2: X(e), y2: yc + 4, stroke: "var(--ink)", "stroke-width": "1.5" }))); }
        g.appendChild(mk("text", { x: X(Math.max(v, ci ? ci[1] : v)) + 8, y: y + 17, "font-size": "12", fill: "var(--ink-2)", "font-variant-numeric": "tabular-nums" }, f1(v)));
        g.appendChild(mk("rect", { class: "hit", x: 0, y: y, width: W, height: rowH, fill: "transparent", rx: 4 }));
        g.addEventListener("pointermove", ev => showTip(x, ev)); g.addEventListener("pointerleave", hideTip);
        g.addEventListener("focus", () => { const b = g.getBoundingClientRect(); showTip(x, { clientX: b.left + Math.min(b.width * 0.5, 400), clientY: b.top + 10 }); }); g.addEventListener("blur", hideTip);
        g.addEventListener("click", () => select(x.r.tag)); g.addEventListener("keydown", ev => { if (ev.key === "Enter" || ev.key === " ") { ev.preventDefault(); select(x.r.tag); } });
        svg.appendChild(g);
      });
      parts.chart.replaceChildren(svg);
    }

    // ---- table
    function cols() {
      const s3 = st.stratum === "0-10" ? "T3 (0–5 at cutoff)" : "T3 (all)";
      if (st.track === "F") return [["index", st.w1 === "1/3" ? "Index" : "Weighted score"], ["T1", "T1 GO, corpus L"], ["T2", "T2 non-GO"], ["T4", "T4 co-ess."], ["S", "S (1–10)"], ["T1_asfound", "T1 as found (1–10)"]];
      return [["index", st.w1 === "1/3" ? "Index" : "Weighted score"], ["ci", "95% gene interval"], ["rank", "Frozen v1 rank (95%)"], ["T1", "T1 GO"], ["T2", "T2 non-GO"], ["T4", "T4 co-ess."], ["T3", s3], ["index4", "Index-4"], ["gen", "Text provenance"], ["n", "Embedded genes (universe)"]];
    }
    function val(x, k) { const p = x.p; switch (k) { case "name": return x.r.name; case "index": return x.idx; case "ci": return x.ci ? x.ci[0] : null; case "rank": return x.rank; case "gen": return x.r.gen_share ?? (x.r.cls === "bio" ? -2 : -1); case "n": return x.r.n_genes; case "T1_asfound": return p["T1_asfound_1-10"]; default: return p[k]; } }
    function provCell(r) { if (r.cls === "bio") return "no text"; if (r.modality === "mixture") return "mixture"; if (r.train_text) return "text in training"; if (r.text === "llm") return "LLM-written, 0%"; return r.gen_share == null ? "–" : Math.round(100 * r.gen_share) + "% generated"; }
    function renderTable() {
      if (compact) return; const cs = cols();
      const thead = el("thead", {}, [el("tr", {}, [el("th", { class: "l sortable", "data-key": "name", text: "Representation", tabindex: "0", "aria-sort": st.sort.key === "name" ? st.sort.dir + "ending" : null }), ...cs.map(([k, l]) => el("th", { class: "sortable", "data-key": k, text: l, tabindex: "0", "aria-sort": st.sort.key === k ? st.sort.dir + "ending" : null }))])]);
      thead.querySelectorAll("th").forEach(th => {
        const sort = () => { const k = th.dataset.key; st.sort = { key: k, dir: st.sort.key === k && st.sort.dir === "desc" ? "asc" : "desc" }; renderTable(); };
        th.addEventListener("click", sort);
        th.addEventListener("keydown", ev => { if (ev.key === "Enter" || ev.key === " ") { ev.preventDefault(); sort(); } });
      });
      const rs = sorted().sort((a, b) => { const va = val(a, st.sort.key), vb = val(b, st.sort.key); const d = typeof va === "string" ? va.localeCompare(vb) : ((va ?? -1e9) - (vb ?? -1e9)); return st.sort.dir === "desc" ? -d : d; });
      const tbody = el("tbody", {}, rs.map(x => { const p = x.p, r = x.r;
        const tds = [el("td", { class: "name l" }, [el("i", { class: "dot " + r.cls }), r.name, r.version === "v1.1" ? " " : null, r.version === "v1.1" ? el("span", { class: "badge v11", text: "v1.1" }) : null, r.encoder && r.track === "O" && r.cls !== "bio" && !r.train_text ? el("span", { class: "dim small", text: " · " + r.encoder }) : null])];
        cs.forEach(([k]) => { let t = "", cls = "num";
          if (k === "index") { t = f1(x.idx); cls += " b"; } else if (k === "ci") { t = x.ci ? f1(x.ci[0]) + "–" + f1(x.ci[1]) : "–"; cls += " dim"; }
          else if (k === "rank") { t = x.rank != null ? String(x.rank) + (x.rank_ci && x.rank_ci[0] !== x.rank_ci[1] ? ` (${x.rank_ci[0]}–${x.rank_ci[1]})` : "") : "–"; }
          else if (k === "gen") { t = provCell(r); cls = "dim"; } else if (k === "n") { t = S.int(r.n_genes); cls += " dim"; }
          else if (k === "S") { t = p.S == null ? "–" : f3(p.S) + (p.S_ci ? ` (${f3(p.S_ci[0])}–${f3(p.S_ci[1])})` : ""); } else if (k === "T1_asfound") { t = f3(p["T1_asfound_1-10"]); } else if (k === "index4") { t = f1(p.index4); cls += " dim"; }
          else { t = f3(p[k]); if (k === "T2" && p.T2_labels) t += " "; }
          const td = el("td", { class: cls }); if (k === "index") td.appendChild(el("b", { text: t })); else if (k === "T2" && p.T2_labels) { td.append(f3(p.T2), el("span", { class: "dim small", text: " (" + p.T2_labels + ")" })); } else td.textContent = t; tds.push(td); });
        const tr = el("tr", { class: st.selected === r.tag ? "sel" : "", "data-tag": r.tag, tabindex: "0" }, tds); tr.addEventListener("click", () => select(r.tag)); tr.addEventListener("keydown", ev => { if (ev.key === "Enter") select(r.tag); }); return tr; }));
      parts.tbl.replaceChildren(el("table", { class: "data" }, [thead, tbody]));
      const ref = D.T3_reference[st.probe];
      parts.note.textContent = st.track === "F"
        ? "Track F scores each embedder on corpus L (GenePT's October-2023 NCBI text with generated summaries removed). S is the per-gene GO AUROC on corpus A (as found) minus corpus L for genes with 1–10 publications: S measures sensitivity to summary removal after refitting both probes, not a causal fraction of copied knowledge. Track F rows have no index or rank intervals in the frozen record."
        : `Click a bar or a row for the full declaration and task profile. T3 reference (literature-only 2023 text, MPNet): ${f3(ref["T3_0-5"])} for genes with 0–5 publications at the cutoff, ${f3(ref["T3_all"])} for all evaluation genes; T3 is shown only for representations eligible under the annotation-access rule and is not part of the index. Index-4 adds T3 for eligible rows.` + (st.w1 !== "1/3" ? ` T1 weight ${st.w1}: the index is recomputed from the frozen task skills as w·T1 + (1−w)/2·(T2+T4); no intervals are shown at this weight.` : "") + " Bars are ordered by the displayed score. Frozen v1 rank intervals compare only the original 20 Track O rows; adding v1.1 rows changes displayed positions, not those historical ranks.";
      renderToolbar();
    }
    function renderToolbar() {
      const n = sorted().length; const left = el("div", { class: "small muted", text: `${n} rows · Track ${st.track} · ${st.stratum === "0-10" ? "genes with 0–10 publications" : "all genes"} · ${st.probe === "mlp" ? "MLP" : "linear"} probe` });
      const dl = el("button", { class: "btn", type: "button", text: "Download this view (TSV)", onclick: downloadView });
      const right = el("div", { class: "actions", style: "margin:0" }, [dl, el("a", { class: "btn", href: "data/leaderboard_v1.tsv", download: "", text: "leaderboard_v1.tsv" }), el("a", { class: "btn", href: "data/leaderboard_v1_1_appended.tsv", download: "", text: "v1.1 appended rows" }), el("a", { class: "btn", href: "data/leaderboard.json", download: "", text: "Full record (JSON)" })]);
      parts.toolbar.replaceChildren(left, right);
    }
    function downloadView() {
      const cs = cols(); const head = ["display_position", "track", "stratum", "probe", "t1_weight", "score_source", "interval_source", "rank_population", "representation", "tag", "version", "modality", "text_provenance", ...cs.map(([k]) => k)];
      const lines = [head.join("\t")]; sorted().forEach(x => { const vals = cs.map(([k]) => { if (k === "ci") return x.ci ? x.ci.join("-") : ""; if (k === "rank") return x.rank ?? ""; if (k === "gen") return provCell(x.r); if (k === "n") return x.r.n_genes; const v = val(x, k); return v == null ? "" : v; });
        lines.push([x.pos, st.track, st.stratum, st.probe, st.w1, x.r.version === "v1" ? "frozen round 11" : "round 14 appended", x.ci ? (x.r.version === "v1" ? "round-11 gene bootstrap" : "round-14 gene bootstrap") : "not available", x.rank != null ? "20 frozen v1 Track O rows" : "not available", x.r.name, x.r.tag, x.r.version, x.r.modality, x.r.text_label, ...vals].join("\t")); });
      const blob = new Blob([lines.join("\n") + "\n"], { type: "text/tab-separated-values" }); const a = document.createElement("a"); a.href = URL.createObjectURL(blob); a.download = `geneprov_${st.track}_${st.stratum}_${st.probe}_${st.version}_w${st.w1.replace("/", "-")}.tsv`; a.click(); setTimeout(() => URL.revokeObjectURL(a.href), 2000);
    }

    // ---- row detail
    function select(tag) { if (compact) { location.href = "leaderboard.html#" + encodeURIComponent(st.track + ":" + tag); return; } st.selected = st.selected === tag ? null : tag; renderTable(); renderDetail(); if (st.selected) parts.detail.scrollIntoView({ block: "nearest" }); }
    function renderDetail() {
      if (compact) return; const r = findRow(st.track, st.selected); if (!r) { parts.detail.replaceChildren(); return; }
      const p = r.probes[st.probe][st.stratum], pl = r.probes.linear["0-10"]; const m = r.meta || {};
      const skillTile = (v, k) => el("div", { class: "skill" }, [el("div", { class: "v", text: v }), el("div", { class: "k", text: k })]);
      const kv = []; const add = (k, v) => { if (v == null || v === "") return; kv.push(el("dt", { text: k }), el("dd", {}, typeof v === "string" ? [v] : v)); };
      add("Track", r.track === "O" ? "O, open representation" : "F, fixed text"); add("Version", r.version + (r.in_v0 ? " (also in v0)" : "")); add("Modality", r.modality);
      add("Embedded text", r.text_label); if (r.encoder) add("Encoder", r.encoder); if (r.train_text) add("Text in training", r.train_text);
      add("Training data", m.training); add("Data date", m.date); add("Annotation or text signal in training", m.signal);
      if (r.track === "O") add("T3 admitted under access rule", (m.t3 || "–") + (m.t3_why ? " — " + m.t3_why : ""));
      if (r.coverage) add("Coverage", `${S.int(r.coverage.n_present)} of ${S.int(D.universe)} genes embedded (${S.pct(r.coverage.share_missing, 1)} receive the mean vector)` + (r.coverage.missing_by_bin ? "; missing by exposure bin: " + Object.entries(r.coverage.missing_by_bin).map(([b, n]) => `${b}: ${n}`).join(", ") : "")); else add("Coverage", `${S.int(r.n_genes)} of ${S.int(D.universe)} genes`);
      if (m.source) add("Source", [el("a", { href: m.source, target: "_blank", rel: "noopener", text: m.source.replace(/^https?:\/\//, "") }), m.cite ? " · " + m.cite : ""]);
      const ints = []; if (pl.ci) ints.push(`gene bootstrap ${f1(pl.ci[0])}–${f1(pl.ci[1])}`); if (pl.ci_family) ints.push(`round-14 regenerated index ${f1(pl.index_r14)}, family interval ${f1(pl.ci_family[0])}–${f1(pl.ci_family[1])}`); if (pl.rank_ci) ints.push(`rank ${pl.rank} (${pl.rank_ci[0]}–${pl.rank_ci[1]})`); if (pl.rank_ci_family) ints.push(`round-14 rank ${pl.rank_r14} (${pl.rank_ci_family[0]}–${pl.rank_ci_family[1]})`);
      if (ints.length) add("Headline intervals (linear, 0–10)", ints.join("; "));
      if (p.T4_recall10 != null) add("T4 recall at 10 (round-14 arrays)", f3(p.T4_recall10) + " (fraction of the ten co-essential partners among the ten nearest genes)");
      if (p.T3_novel != null) add("T3 novel-pair targets", f3(p.T3_novel) + " (targets no family member carried at the cutoff)");
      const head = el("div", {}, [el("button", { class: "btn close", type: "button", text: "Close", onclick: () => select(r.tag) }), el("h3", { style: "margin-top:4px" }, [el("i", { class: "dot " + r.cls }), r.name, " ", el("span", { class: "badge" + (r.version === "v1.1" ? " v11" : ""), text: r.version })]), el("p", { class: "small muted", text: `${st.stratum === "0-10" ? "Genes with 0–10 publications" : "All genes"} · ${st.probe === "mlp" ? "MLP" : "linear"} probe` })]);
      const skills = el("div", { class: "skills" }, [skillTile(f1(indexAt(p, st.w1)), scoreLabel(st.w1)), skillTile(f1(p.skills.T1), "T1 skill (AUROC " + f3(p.T1) + ")"), skillTile(f1(p.skills.T2), "T2 skill (AUROC " + f3(p.T2) + ", " + (p.T2_labels || 0) + " labels)"), skillTile(f1(p.skills.T4), "T4 skill (AUROC " + f3(p.T4) + ")"), p.T3 != null ? skillTile(f1(p.skills.T3), "T3 skill (AUROC " + f3(p.T3) + (p.T3_n ? ", " + p.T3_n + " genes" : "") + ")") : null, p.index4 != null ? skillTile(f1(p.index4), "Index-4 (with T3)") : null, p.S != null ? skillTile(f3(p.S), "S, summary sensitivity (1–10)") : null]);
      if (p.T1_n != null) add("T1 evaluated genes", S.int(p.T1_n) + " in this stratum (genes meeting the GO scoring rule)");
      if (p.T4_n != null) add("T4 evaluated genes", S.int(p.T4_n) + " in this stratum (genes with co-essentiality labels)");
      const extras = [];
      if (p.T2_per_label) { const rows = Object.entries(p.T2_per_label).filter(([, v]) => v != null).sort((a, b) => b[1] - a[1]);
        extras.push(el("h3", { text: "T2 by label" + (p.T2_per_label_source ? " (" + p.T2_per_label_source + ")" : "") }), el("div", { class: "tbl-wrap" }, [el("table", { class: "data" }, [el("thead", {}, [el("tr", {}, [el("th", { class: "l", text: "Label" }), el("th", { text: "AUROC" })])]), el("tbody", {}, rows.map(([k, v]) => el("tr", {}, [el("td", { class: "l", text: LABELS[k] || k }), el("td", { class: "num", text: f3(v) })])))])])); }
      if (p.T1_bins) { extras.push(el("h3", { text: "T1 by literature exposure (publications linked to the gene)" }), el("div", { class: "tbl-wrap" }, [el("table", { class: "data" }, [el("thead", {}, [el("tr", {}, Object.keys(p.T1_bins).map(b => el("th", { text: b })))]), el("tbody", {}, [el("tr", {}, Object.values(p.T1_bins).map(v => el("td", { class: "num", text: f3(v) })))])])])); }
      parts.detail.replaceChildren(el("div", { class: "card" }, [head, skills, el("dl", { class: "kv" }, kv), ...extras]));
    }
    function renderT3Only() {
      if (compact) return; const rs = D.rows.filter(r => r.t3_only && st.version === "v1.1" && st.track === "O"); if (!rs.length) { parts.t3only.replaceChildren(); return; }
      const cell = (r, pr, k) => f3(r.probes[pr]["0-10"][k === "T3" ? "T3" : "T3_novel"]), cellA = (r, pr, k) => f3(r.probes[pr]["all"][k === "T3" ? "T3" : "T3_novel"]);
      parts.t3only.replaceChildren(el("h3", { text: "Appended T3-only reference rows (v1.1)" }), el("p", { class: "footnote", text: "The gene's own GO annotation vector at the 2023 cutoff is a reference for the annotation-holdout task, not a gene representation; it has no T1, T2 or T4 score and no index. Columns: per-gene AUROC on the primary targets and on novel-pair targets, for genes with 0–5 publications at the cutoff and for all 347 evaluation genes." }),
        el("div", { class: "tbl-wrap" }, [el("table", { class: "data" }, [el("thead", {}, [el("tr", {}, [el("th", { class: "l", text: "Row" }), el("th", { text: "Probe" }), el("th", { text: "T3 (0–5)" }), el("th", { text: "novel (0–5)" }), el("th", { text: "T3 (all)" }), el("th", { text: "novel (all)" })])]),
          el("tbody", {}, rs.flatMap(r => ["linear", "mlp"].map(pr => el("tr", {}, [el("td", { class: "l name" }, [el("i", { class: "dot annot" }), r.name]), el("td", { text: pr === "mlp" ? "MLP" : "linear" }), el("td", { class: "num", text: cell(r, pr, "T3") }), el("td", { class: "num", text: cell(r, pr, "novel") }), el("td", { class: "num", text: cellA(r, pr, "T3") }), el("td", { class: "num", text: cellA(r, pr, "novel") })]))))])]));
    }
    function renderFamily() {
      if (compact) return;
      if (st.intervals !== "family") { parts.family.replaceChildren(); return; }
      const rs = D.rows.filter(r => r.track === "O" && r.version === "v1" && r.probes.linear["0-10"].ci_family)
        .sort((a, b) => b.probes.linear["0-10"].index_r14 - a.probes.linear["0-10"].index_r14);
      parts.family.replaceChildren(el("h3", { text: "Family sensitivity: separate round-14 regeneration" }),
        el("p", { class: "footnote", text: "Linear probe, 0–10 publications, original 20 Track O rows only. These estimates use regenerated arrays, including a new ESM2 embedding, so their family intervals accompany their own point estimates and ranks. The frozen leaderboard above stays unchanged. No family analysis is available for MLP, all genes, Track F or appended rows." }),
        el("div", { class: "tbl-wrap" }, [el("table", { class: "data" }, [
          el("thead", {}, [el("tr", {}, ["Representation", "Regenerated index", "95% family interval", "Regenerated rank (95%)"].map(t => el("th", { text: t })))]),
          el("tbody", {}, rs.map(r => { const p = r.probes.linear["0-10"]; return el("tr", {}, [el("td", { class: "l", text: r.name }), el("td", { text: f1(p.index_r14) }), el("td", { text: p.ci_family.map(f1).join("–") }), el("td", { text: p.rank_r14 + " (" + p.rank_ci_family.join("–") + ")" })]); }))]) ]));
    }
    function render() { renderKpis(); renderLegend(); renderChart(); renderTable(); renderDetail(); renderFamily(); renderT3Only(); }
    document.addEventListener("geneprov:theme", render);
    render();
    if (!compact && location.hash.length > 1) {
      const hash = decodeURIComponent(location.hash.slice(1)); const colon = hash.indexOf(":");
      const track = colon >= 0 ? hash.slice(0, colon) : "O", tag = colon >= 0 ? hash.slice(colon + 1) : hash;
      const row = findRow(track, tag);
      if (row) { st.track = row.track; if (row.version === "v1.1") st.version = "v1.1"; syncChips(); render(); select(tag); }
    }
    return { state: st, render };
  }
  return { mount, CLS, indexAt, viewRows, findRow, makeState };
})();
