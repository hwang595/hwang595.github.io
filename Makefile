RBENV := $(shell command -v rbenv 2>/dev/null)
RUBY ?= $(if $(RBENV),$(RBENV) exec ruby,ruby)
BUNDLE ?= $(if $(RBENV),$(RBENV) exec bundle,bundle)
PUBLICATION ?= scripts/templates/publication.yml
TOPICS ?=
TOPIC_OPTIONS := $(if $(TOPICS),--topics "$(TOPICS)",)

.PHONY: validate build serve preview-publication new-publication link-list check-links quality-audit quality lighthouse

validate:
	$(RUBY) scripts/publication_tools.rb validate

build:
	$(BUNDLE) exec jekyll build --trace

serve:
	$(BUNDLE) exec jekyll serve --host 127.0.0.1 --port 4001 --trace

preview-publication:
	$(RUBY) scripts/publication_tools.rb new $(PUBLICATION) $(TOPIC_OPTIONS) --dry-run

new-publication:
	$(RUBY) scripts/publication_tools.rb new $(PUBLICATION) $(TOPIC_OPTIONS)

link-list:
	$(RUBY) scripts/publication_tools.rb check-links --dry-run

check-links:
	$(RUBY) scripts/publication_tools.rb check-links

quality-audit:
	$(BUNDLE) exec ruby scripts/quality_tools.rb audit

quality: build quality-audit

lighthouse:
	@command -v npx >/dev/null || (echo "npx is required for Lighthouse CI. Install Node.js or run in an environment with npx."; exit 1)
	npx --yes @lhci/cli autorun
