# Website Maintenance Audit

Reviewed locally before commit or deployment on September 20, 2026.

## Fixed

- Four publication URLs returned HTTP 404. Replaced them with verified official pages for [Accordion](https://proceedings.mlsys.org/paper_files/paper/2021/hash/acd593d2db87a799a8d3da5a860c028e-Abstract.html), [Pufferfish](https://proceedings.mlsys.org/paper_files/paper/2021/hash/94cb28874a503f34b3c4a41bddcea2bd-Abstract.html), [Gradient Compression Utility](https://proceedings.mlsys.org/paper_files/paper/2022/hash/773862fcc2e29f650d68960ba5bd1101-Abstract.html), and [FedMA](https://iclr.cc/virtual_2020/poster_BkluqlSFDS.html).
- Cuttlefish and Crystal linked to different papers. Corrected both the card metadata and inline citations using the official [Cuttlefish](https://arxiv.org/abs/2305.02538) and [Crystal](https://arxiv.org/abs/2411.04156) arXiv records.
- Homepage citation-copy buttons lacked a handler. Extracted a shared handler for every publication card, with clipboard fallback and restored keyboard focus.
- Publication searches omitted topic tags. Added topics to search text, exposed filter selection through `aria-pressed`, and hid the earlier-publications section when it has no matching papers.
- Clarified that publication filters do not apply to the separately listed technical reports.
- Removed the duplicate News heading and added accessible news filter states and result announcements.
- Fixed the mobile contact dropdown appearing behind page text. Added accessible disclosure state, outside-click dismissal, Escape dismissal, and versioning of the maintenance script to prevent stale cached behavior.
- Replaced the outdated HTML CV with a link to the existing PDF, preserving the CV and resume URLs. The PDF itself was not edited or fact-checked.
- Replaced placeholder courses with one shared teaching data file used by both the homepage and teaching page.
- Excluded template posts, sample courses/portfolio pages, demo archives, and development utilities from deployment. Source files are retained.
- Expanded the quality audit to catch missing assets, duplicate primary headings, missing citation handlers, inaccessible filter states, and missing searchable topics. Publication validation now warns when different records share an arXiv/OpenReview URL.
- Preserved the new ICLR 2027 Area Chair announcement and service entry.

## Verification

- Jekyll production build: passed using the installed GitHub Pages dependencies.
- Generated HTML audit: 59 files, zero warnings; includes internal links, metadata, accessibility basics, image budgets, and local script/stylesheet existence.
- Publication metadata: 41 records validated.
- Auto-updater configuration audit: passed; no publication sources are configured.
- External publication-link check: 56 OK, two warnings, zero confirmed hard failures.
- JavaScript and Ruby syntax checks, plus `git diff --check`: passed.
- Regression checks: deliberately introduced five generated-page faults in a temporary copy; all were detected. A duplicate paper URL was also detected.
- Browser checks: desktop homepage; mobile homepage, research, group, and publications layouts; navigation and contact-menu dismissal; homepage BibTeX copying; publication topic search, empty results, and earlier-year filters; news filtering and the ICLR announcement; teaching content.

## Follow-Up Items

1. The SysML 2018 Draco link has a TLS certificate error. Find an authoritative replacement for that specific workshop version; do not silently replace it with a different version or disable certificate verification.
2. ACM returns HTTP 403 to the automated checker. Manually verify access to the SIGMOD 2019 paper; this is not evidence that the paper is missing.
3. The 2016 terms/privacy page still describes Disqus and advertising. Review its factual accuracy before rewriting it. Analytics is currently disabled.
4. Legacy theme Sass emits deprecation warnings. Plan dependency modernization separately rather than mixing a theme/runtime upgrade into this content release.
5. On mobile, the publication filter list is long. A collapsible advanced-filter panel would reduce scrolling; keep search visible.
6. Confirm that the PDF CV reflects any Fall 2026 changes. The newer Fall 2026 course content was preserved during PR preparation, as described below. No biographical or course details were invented during this audit.
7. Tracked `.DS_Store` and Sass cache files are repository housekeeping candidates. The pre-existing `.DS_Store` modification was left untouched and should not be included in this maintenance commit.

## PR Integration Check

- Based the maintenance branch on the latest `master`, including the merged NYC 311 challenge and teaching-figure work.
- Added Fall 2026 CS 439 to the shared course list. Both the homepage and teaching page now show all three courses with the correct challenge link.
- Retained the challenge description, Canvas/CodeBench announcement note, full challenge page, starter script, and synthetic teaching figures.
- Configured `titles_from_headings.strip_title` so Jekyll renders inferred Markdown titles only once, fixing the generated course-guide headings. Explicit page titles and course Markdown files remain unchanged.
- Rebuilt the integrated site: 64 generated HTML files pass the quality audit with zero warnings; publication metadata and auto-updater checks also pass.

This was not a full accessibility conformance, security, or cross-browser audit. At the end of the initial audit, no commit, push, or public deployment had been performed; the subsequent PR preparation includes the integration checks above.
