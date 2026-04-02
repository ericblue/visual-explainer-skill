SKILL_NAME    := visual-explainer
SKILL_DIR     := skill
SKILL_FILE    := $(SKILL_DIR)/$(SKILL_NAME).md
METADATA_FILE := $(SKILL_DIR)/metadata.json
INSTALL_DIR   := $(HOME)/.claude/commands
VERSION       := $(shell jq -r '.version' $(METADATA_FILE))

.PHONY: install uninstall version check info bump-patch bump-minor bump-major set-version release

install: check
	@mkdir -p $(INSTALL_DIR)
	@cp $(SKILL_FILE) $(INSTALL_DIR)/$(SKILL_NAME).md
	@echo "Installed $(SKILL_NAME) v$(VERSION) to $(INSTALL_DIR)/$(SKILL_NAME).md"

uninstall:
	@rm -f $(INSTALL_DIR)/$(SKILL_NAME).md
	@echo "Uninstalled $(SKILL_NAME) from $(INSTALL_DIR)"

version:
	@echo $(VERSION)

check:
	@if [ ! -f $(SKILL_FILE) ]; then \
		echo "Error: $(SKILL_FILE) not found"; exit 1; \
	fi
	@if [ ! -f $(METADATA_FILE) ]; then \
		echo "Error: $(METADATA_FILE) not found"; exit 1; \
	fi
	@command -v jq >/dev/null 2>&1 || { echo "Error: jq is required (brew install jq)"; exit 1; }
	@if [ -z "$$OPENAI_API_KEY" ]; then \
		echo "Warning: OPENAI_API_KEY is not set — the skill will not work without it"; \
	fi
	@echo "All checks passed"

info:
	@echo "Name:        $(SKILL_NAME)"
	@echo "Version:     $(VERSION)"
	@echo "Author:      $(shell jq -r '.author.name' $(METADATA_FILE))"
	@echo "Description: $(shell jq -r '.description' $(METADATA_FILE))"
	@echo "Styles:      $(shell jq -r '.styles | join(", ")' $(METADATA_FILE))"
	@echo "Install dir: $(INSTALL_DIR)"

# --- Version management ---

bump-patch:
	@NEW_VERSION=$$(echo $(VERSION) | awk -F. '{print $$1"."$$2"."$$3+1}'); \
	jq --arg v "$$NEW_VERSION" '.version = $$v | .updated = (now | strftime("%Y-%m-%d"))' $(METADATA_FILE) > $(METADATA_FILE).tmp && \
	mv $(METADATA_FILE).tmp $(METADATA_FILE); \
	echo "Bumped version: $(VERSION) → $$NEW_VERSION"

bump-minor:
	@NEW_VERSION=$$(echo $(VERSION) | awk -F. '{print $$1"."$$2+1".0"}'); \
	jq --arg v "$$NEW_VERSION" '.version = $$v | .updated = (now | strftime("%Y-%m-%d"))' $(METADATA_FILE) > $(METADATA_FILE).tmp && \
	mv $(METADATA_FILE).tmp $(METADATA_FILE); \
	echo "Bumped version: $(VERSION) → $$NEW_VERSION"

bump-major:
	@NEW_VERSION=$$(echo $(VERSION) | awk -F. '{print $$1+1".0.0"}'); \
	jq --arg v "$$NEW_VERSION" '.version = $$v | .updated = (now | strftime("%Y-%m-%d"))' $(METADATA_FILE) > $(METADATA_FILE).tmp && \
	mv $(METADATA_FILE).tmp $(METADATA_FILE); \
	echo "Bumped version: $(VERSION) → $$NEW_VERSION"

set-version:
	@if [ -z "$(V)" ]; then echo "Usage: make set-version V=1.2.3"; exit 1; fi
	@echo $(V) | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "Error: version must be semver (e.g., 1.2.3)"; exit 1; }
	@jq --arg v "$(V)" '.version = $$v | .updated = (now | strftime("%Y-%m-%d"))' $(METADATA_FILE) > $(METADATA_FILE).tmp && \
	mv $(METADATA_FILE).tmp $(METADATA_FILE)
	@echo "Set version: $(VERSION) → $(V)"

release: check
	@echo "Releasing $(SKILL_NAME) v$(VERSION)..."
	@git add $(METADATA_FILE) $(SKILL_FILE)
	@git commit -m "Release v$(VERSION)"
	@git tag -a "v$(VERSION)" -m "Release v$(VERSION)"
	@echo "Created commit and tag v$(VERSION)"
	@echo "Run 'git push && git push --tags' to publish"
