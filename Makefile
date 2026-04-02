SKILL_NAME    := visual-explainer
SKILL_DIR     := skill
SKILL_FILE    := $(SKILL_DIR)/$(SKILL_NAME).md
METADATA_FILE := $(SKILL_DIR)/metadata.json
VERSION       := $(shell jq -r '.version' $(METADATA_FILE))

# Install paths
CLAUDE_COMMANDS_DIR := $(HOME)/.claude/commands
OPENCLAW_SKILLS_DIR ?= $(HOME)/clawd/skills

.PHONY: help install uninstall version check info \
	openclaw-install openclaw-uninstall openclaw-check \
	bump-patch bump-minor bump-major set-version release

.DEFAULT_GOAL := help

help: ## Show this help
	@echo "$(SKILL_NAME) v$(VERSION)"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Claude Code:"
	@grep -E '^(install|uninstall|check):' $(MAKEFILE_LIST) | grep '##' | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-25s %s\n", $$1, $$2}'
	@echo ""
	@echo "OpenClaw:"
	@grep -E '^openclaw-' $(MAKEFILE_LIST) | grep '##' | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-25s %s\n", $$1, $$2}'
	@echo ""
	@echo "Version & Release:"
	@grep -E '^(version|info|bump-patch|bump-minor|bump-major|set-version|release):' $(MAKEFILE_LIST) | grep '##' | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-25s %s\n", $$1, $$2}'

# ============================================================================
# Claude Code
# ============================================================================

install: check ## Install skill to ~/.claude/commands/
	@mkdir -p $(CLAUDE_COMMANDS_DIR)
	@cp $(SKILL_FILE) $(CLAUDE_COMMANDS_DIR)/$(SKILL_NAME).md
	@echo "Installed $(SKILL_NAME) v$(VERSION) to $(CLAUDE_COMMANDS_DIR)/$(SKILL_NAME).md"

uninstall: ## Remove skill from ~/.claude/commands/
	@rm -f $(CLAUDE_COMMANDS_DIR)/$(SKILL_NAME).md
	@echo "Uninstalled $(SKILL_NAME) from $(CLAUDE_COMMANDS_DIR)"

version: ## Print current version
	@echo $(VERSION)

check: ## Verify skill files and dependencies
	@if [ ! -f $(SKILL_FILE) ]; then \
		echo "Error: $(SKILL_FILE) not found"; exit 1; \
	fi
	@if [ ! -f $(METADATA_FILE) ]; then \
		echo "Error: $(METADATA_FILE) not found"; exit 1; \
	fi
	@command -v jq >/dev/null 2>&1 || { echo "Error: jq is required (brew install jq)"; exit 1; }
	@if [ -z "$$OPENAI_API_KEY" ] && [ -z "$$GEMINI_API_KEY" ]; then \
		echo "Warning: No image generation API key found. Set at least one:"; \
		echo "  export OPENAI_API_KEY=\"sk-...\"    # from platform.openai.com"; \
		echo "  export GEMINI_API_KEY=\"AIza...\"   # from aistudio.google.com/apikey"; \
	elif [ -n "$$OPENAI_API_KEY" ] && [ -n "$$GEMINI_API_KEY" ]; then \
		echo "API keys: OpenAI (set), Gemini (set) — default backend: OpenAI"; \
	elif [ -n "$$OPENAI_API_KEY" ]; then \
		echo "API key: OpenAI (set)"; \
	else \
		echo "API key: Gemini (set)"; \
	fi
	@echo "All checks passed"

info: ## Show skill metadata
	@echo "Name:        $(SKILL_NAME)"
	@echo "Version:     $(VERSION)"
	@echo "Author:      $(shell jq -r '.author.name' $(METADATA_FILE))"
	@echo "Description: $(shell jq -r '.description' $(METADATA_FILE))"
	@echo "Styles:      $(shell jq -r '.styles | join(", ")' $(METADATA_FILE))"

# ============================================================================
# OpenClaw
# ============================================================================

openclaw-install: check ## Install skill to ~/clawd/skills/
	@mkdir -p $(OPENCLAW_SKILLS_DIR)/$(SKILL_NAME)
	@cp $(SKILL_FILE) $(OPENCLAW_SKILLS_DIR)/$(SKILL_NAME)/SKILL.md
	@cp $(METADATA_FILE) $(OPENCLAW_SKILLS_DIR)/$(SKILL_NAME)/metadata.json
	@echo "Installed $(SKILL_NAME) v$(VERSION) to $(OPENCLAW_SKILLS_DIR)/$(SKILL_NAME)/SKILL.md"

openclaw-uninstall: ## Remove skill from ~/clawd/skills/
	@if [ -d $(OPENCLAW_SKILLS_DIR)/$(SKILL_NAME) ]; then \
		rm -rf $(OPENCLAW_SKILLS_DIR)/$(SKILL_NAME); \
		echo "Uninstalled $(SKILL_NAME) from $(OPENCLAW_SKILLS_DIR)"; \
	else \
		echo "$(SKILL_NAME) not installed in OpenClaw"; \
	fi

openclaw-check: ## Check if skill is installed in OpenClaw
	@echo "OpenClaw Skill Status"
	@echo "====================="
	@echo "Skills directory: $(OPENCLAW_SKILLS_DIR)"
	@echo ""
	@if [ -f $(OPENCLAW_SKILLS_DIR)/$(SKILL_NAME)/SKILL.md ]; then \
		echo "$(SKILL_NAME): INSTALLED"; \
		echo "  Location: $(OPENCLAW_SKILLS_DIR)/$(SKILL_NAME)/SKILL.md"; \
	else \
		echo "$(SKILL_NAME): NOT INSTALLED"; \
		echo "  Run: make openclaw-install"; \
	fi

# --- Version management ---

bump-patch: ## Bump patch version (x.y.Z)
	@NEW_VERSION=$$(echo $(VERSION) | awk -F. '{print $$1"."$$2"."$$3+1}'); \
	jq --arg v "$$NEW_VERSION" '.version = $$v | .updated = (now | strftime("%Y-%m-%d"))' $(METADATA_FILE) > $(METADATA_FILE).tmp && \
	mv $(METADATA_FILE).tmp $(METADATA_FILE); \
	echo "Bumped version: $(VERSION) → $$NEW_VERSION"

bump-minor: ## Bump minor version (x.Y.0)
	@NEW_VERSION=$$(echo $(VERSION) | awk -F. '{print $$1"."$$2+1".0"}'); \
	jq --arg v "$$NEW_VERSION" '.version = $$v | .updated = (now | strftime("%Y-%m-%d"))' $(METADATA_FILE) > $(METADATA_FILE).tmp && \
	mv $(METADATA_FILE).tmp $(METADATA_FILE); \
	echo "Bumped version: $(VERSION) → $$NEW_VERSION"

bump-major: ## Bump major version (X.0.0)
	@NEW_VERSION=$$(echo $(VERSION) | awk -F. '{print $$1+1".0.0"}'); \
	jq --arg v "$$NEW_VERSION" '.version = $$v | .updated = (now | strftime("%Y-%m-%d"))' $(METADATA_FILE) > $(METADATA_FILE).tmp && \
	mv $(METADATA_FILE).tmp $(METADATA_FILE); \
	echo "Bumped version: $(VERSION) → $$NEW_VERSION"

set-version: ## Set version (make set-version V=1.2.3)
	@if [ -z "$(V)" ]; then echo "Usage: make set-version V=1.2.3"; exit 1; fi
	@echo $(V) | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "Error: version must be semver (e.g., 1.2.3)"; exit 1; }
	@jq --arg v "$(V)" '.version = $$v | .updated = (now | strftime("%Y-%m-%d"))' $(METADATA_FILE) > $(METADATA_FILE).tmp && \
	mv $(METADATA_FILE).tmp $(METADATA_FILE)
	@echo "Set version: $(VERSION) → $(V)"

release: check ## Tag and commit a release
	@echo "Releasing $(SKILL_NAME) v$(VERSION)..."
	@git add $(METADATA_FILE) $(SKILL_FILE)
	@git commit -m "Release v$(VERSION)"
	@git tag -a "v$(VERSION)" -m "Release v$(VERSION)"
	@echo "Created commit and tag v$(VERSION)"
	@echo "Run 'git push && git push --tags' to publish"
