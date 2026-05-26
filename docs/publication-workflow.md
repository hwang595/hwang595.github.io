# Publication Maintenance Workflow

This site has a lightweight data-driven workflow for publications and technical reports. The goal is that a new paper only needs a YAML file or BibTeX entry, plus a short topic list.

## Daily Commands

```bash
make validate
make preview-publication PUBLICATION=scripts/templates/publication.yml
make preview-publication PUBLICATION=scripts/templates/publication.bib TOPICS="LLM Systems,Data & Evaluation"
make new-publication PUBLICATION=path/to/publication.yml
make link-list
make build
```

`make link-list` only inventories URLs and does not touch the network. `make check-links` performs live HTTP checks and is better for scheduled CI because publisher sites sometimes rate-limit local requests.

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

Use `collection: technical_reports` for a technical report. The script writes to `_technical_reports/` and adds `type: "Technical report"` automatically.

## Add From BibTeX

Start from `scripts/templates/publication.bib` or paste a downloaded BibTeX entry into a scratch file:

```bash
ruby scripts/publication_tools.rb new paper.bib \
  --topics "LLM Systems,Data & Evaluation" \
  --dry-run
```

BibTeX import now parses nested braces and infers common metadata:

- `booktitle`, `journal`, `venue`, `archivePrefix`, and URLs are mapped to canonical venues such as `ICLR`, `ICML`, `NeurIPS`, `COLM`, `arXiv`, and `bioRxiv`.
- `url`, `doi`, and arXiv `eprint` fields become structured links.
- arXiv/bioRxiv-only entries are routed to `technical_reports`; conference/journal entries stay in `publications`.
- Existing titles are checked before writing. Use `--allow-duplicate` only when the duplicate is intentional.

YAML is still preferred when you want abstracts, highlights, multiple custom links, or a hand-tuned slug.

## Validate Before Build

Run this before opening a PR:

```bash
make validate
make link-list
bundle exec jekyll build --trace
```

The validator checks active files in `_publications/*.md` and `_technical_reports/*.md`. It ignores archived files in nested folders such as `_publications/__old/`.

It verifies:

- Required front matter: `title`, `date`, `venue`, `pubtype`, and `excerpt`
- `pubtype` matches the year parsed from `date`
- Technical reports use `type: "Technical report"`
- Every active publication has topics in `_data/publication_topics.yml`
- Every active publication has at least one link in structured data, front matter, or its excerpt
- Structured link entries have `label` and `url`
- Topic/link/highlight/featured/research-theme data does not reference stale publication slugs
- Active publication titles are not duplicated
- Repeated URLs inside the same structured link list are reported as warnings

GitHub Actions runs metadata validation and a Jekyll build on pull requests. A scheduled weekly workflow runs live publication link checks and only fails for clearly broken links such as 404/410 or invalid URLs; timeouts, TLS issues, 403s, and 5xx responses are reported as warnings.
