# Academic Website Auto-Updater v2

This project now has a lightweight automation layer for keeping the academic website data-driven and reviewable.

## What It Does

- Imports new publications from arXiv metadata or exported BibTeX.
- Reuses the existing publication generator to create publication cards and update topics/links data.
- Suggests selected papers from pinned slugs, topics, year, and highlight metadata.
- Audits the automation config in CI without making network requests.
- Keeps group members, research projects, and news entries data-driven through YAML/front matter templates.
- Uses the existing Jekyll feed for RSS and the existing GitHub Pages workflow for deployment.

## Safe Source Policy

Google Scholar should not be scraped. If Scholar is the source of truth, export BibTeX manually and import that file as `google_scholar_manual`.

Preferred sources:

- arXiv IDs through the arXiv API
- BibTeX exported from DBLP
- BibTeX exported from Semantic Scholar
- BibTeX exported from OpenReview, publisher pages, or Google Scholar
- Hand-reviewed YAML for papers that need custom abstracts, topics, or links

## Common Commands

```bash
make auto-plan
make auto-audit
make suggest-selected
make sync-publications
```

All write-capable commands dry-run by default. To write changes:

```bash
make sync-publications APPLY=1
make suggest-selected APPLY=1
```

Import one arXiv paper directly:

```bash
ruby scripts/auto_updater.rb import-arxiv 2606.00395 --topics "LLM Systems,MoE Systems,Reinforcement Learning" --apply
```

Import one BibTeX file:

```bash
ruby scripts/auto_updater.rb import-bibtex path/to/paper.bib --topics "LLM Systems,Data & Evaluation" --apply
```

## Configured Sync Queue

Add pending publication sources to `_data/auto_updater.yml`:

```yaml
publication_sync:
  sources:
    - kind: arxiv
      id: "2606.00395"
      collection: "technical_reports"
      topics:
        - LLM Systems
        - MoE Systems
        - Reinforcement Learning
```

Then run:

```bash
make sync-publications
```

Review the dry-run output. If it looks right:

```bash
make sync-publications APPLY=1
make validate
make quality
```

## Data-Driven Content

Templates live in `scripts/templates/`:

- `publication.yml`
- `publication.bib`
- `news.yml`
- `group-member.yml`
- `research-project.yml`

Group members live in `_data/group.yml`, research project entry points live in `_data/research_themes.yml`, and news entries live in `_news/`.

## CI/CD

Pull requests run:

- auto-updater config audit
- publication metadata validation
- publication link inventory
- Jekyll build
- generated-site quality audit

The scheduled link-check workflow still checks publication links. RSS is provided by `jekyll-feed`, and deployment remains GitHub Pages-first. `vercel.json` is included as an optional static deployment config for Vercel.
