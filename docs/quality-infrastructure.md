# Quality Infrastructure

This site now has a lightweight quality layer around the Jekyll build.

## Local Checks

```bash
make validate
make link-list
make quality
```

`make quality` runs a full Jekyll build and then audits the generated `_site` output for:

- Missing titles, descriptions, canonical URLs, and language attributes
- Images without alt text
- Buttons and links without accessible names
- Duplicate IDs and unlabeled form controls
- Broken internal links and missing hash fragments
- Generated `robots.txt` and `sitemap.xml`
- Rendered image weight budgets

For a live external publication link check:

```bash
make check-links
```

That command uses network requests and treats only clearly broken links, such as 404/410 and invalid URLs, as hard failures.

## Lighthouse

Lighthouse CI config lives in `.lighthouserc.json`. After `make build`, run:

```bash
make lighthouse
```

The config checks the home page, publications page, group page, and research page. It currently warns on category thresholds rather than failing the build, which keeps CI practical while the site is still evolving.
This requires Node.js with `npx` available; the Makefile target will print a short setup hint if Lighthouse cannot run locally.

## Analytics

Analytics is disabled by default. To enable Plausible:

```yaml
analytics:
  provider: "plausible"
  plausible:
    domain: "hwang595.github.io"
```

To enable GA4:

```yaml
analytics:
  provider: "google-gtag"
  google:
    measurement_id: "G-XXXXXXXXXX"
```

Avoid enabling the legacy Google Universal Analytics provider unless there is a specific migration reason.
