# Publication Maintenance Workflow

This site now has a lightweight data-driven workflow for publications and technical reports.

## Add From YAML

1. Copy `scripts/templates/publication.yml` to a scratch file.
2. Fill in `slug`, `collection`, `title`, `authors`, `venue`, `date`, `links`, `topics`, and optional `abstract` / `bibtex`.
3. Preview the generated publication file:

```bash
ruby scripts/publication_tools.rb new path/to/publication.yml --dry-run
```

4. Generate the publication card data:

```bash
ruby scripts/publication_tools.rb new path/to/publication.yml
```

Use `collection: technical_reports` for a technical report. The script will write to `_technical_reports/` and add `type: "Technical report"` automatically.

## Add From BibTeX

BibTeX can be used as the starting point, with site-specific metadata supplied on the command line:

```bash
ruby scripts/publication_tools.rb new paper.bib \
  --collection publications \
  --venue ICLR \
  --date 2026-05-01 \
  --topics "LLM Systems,Data & Evaluation"
```

BibTeX generation extracts title, authors, year, venue, URL, and the raw BibTeX block when those fields are present. YAML is still preferred when you want abstracts, highlights, or multiple links.

## Validate Before Build

Run this before opening a PR:

```bash
ruby scripts/publication_tools.rb validate
bundle exec jekyll build --trace
```

The validator checks active files in `_publications/*.md` and `_technical_reports/*.md`. It ignores archived files in nested folders such as `_publications/__old/`.

It currently verifies:

- Required front matter: `title`, `date`, `venue`, `pubtype`, and `excerpt`
- `pubtype` matches the year parsed from `date`
- Technical reports use `type: "Technical report"`
- Every active publication has topics in `_data/publication_topics.yml`
- Every active publication has at least one link in structured data, front matter, or its excerpt
- Structured link entries have `label` and `url`
- Topic/link/highlight/featured data does not reference stale publication slugs

GitHub Actions runs the same validation before the Jekyll build.
