RBENV := $(shell command -v rbenv 2>/dev/null)
RUBY ?= $(if $(RBENV),$(RBENV) exec ruby,ruby)
BUNDLE ?= $(if $(RBENV),$(RBENV) exec bundle,bundle)
PUBLICATION ?= scripts/templates/publication.yml
TOPICS ?=
TOPIC_OPTIONS := $(if $(TOPICS),--topics "$(TOPICS)",)
APPLY ?= 0
APPLY_OPTION := $(if $(filter 1 true yes,$(APPLY)),--apply,)

.PHONY: validate build serve preview-publication new-publication link-list check-links auto-plan auto-audit sync-publications suggest-selected quality-audit quality lighthouse

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

auto-plan:
	$(RUBY) scripts/auto_updater.rb plan

auto-audit:
	$(RUBY) scripts/auto_updater.rb audit

sync-publications:
	$(RUBY) scripts/auto_updater.rb sync-publications $(APPLY_OPTION)

suggest-selected:
	$(RUBY) scripts/auto_updater.rb suggest-selected $(APPLY_OPTION)

quality-audit:
	$(BUNDLE) exec ruby scripts/quality_tools.rb audit

quality: auto-audit build quality-audit

lighthouse:
	@command -v npx >/dev/null || (echo "npx is required for Lighthouse CI. Install Node.js or run in an environment with npx."; exit 1)
	npx --yes @lhci/cli autorun
