# Releasing

This document covers how to cut a new release of the visual-explainer skill.

## Versioning

This project follows [Semantic Versioning](https://semver.org/):

- **Patch** (`1.0.x`) — bug fixes, prompt tweaks, typo corrections
- **Minor** (`1.x.0`) — new styles, new flags, new features (backward-compatible)
- **Major** (`x.0.0`) — breaking changes to flags, removed styles, changed output format

The version is stored in `skill/metadata.json` and managed via Makefile targets.

## Release Process

### 1. Verify everything is clean

```bash
git status              # no uncommitted changes
make check              # prerequisites pass
make info               # review current version
```

### 2. Bump the version

Pick the appropriate bump level:

```bash
make bump-patch         # 1.0.0 → 1.0.1
make bump-minor         # 1.0.0 → 1.1.0
make bump-major         # 1.0.0 → 2.0.0

# Or set an exact version:
make set-version V=2.1.0
```

This updates `version` and `updated` date in `skill/metadata.json`.

### 3. Update the changelog (if applicable)

If you maintain a changelog, add an entry for the new version describing what changed.

### 4. Test the install

```bash
make install            # installs to ~/.claude/commands/
```

Open a new Claude Code session and verify `/visual-explainer` works as expected.

### 5. Commit, tag, and push

```bash
make release            # commits metadata + skill, creates git tag
git push && git push --tags
```

The `make release` target:
- Stages `skill/metadata.json` and `skill/visual-explainer.md`
- Creates a commit: `Release v<version>`
- Creates an annotated git tag: `v<version>`

### 6. Create a GitHub release (optional)

```bash
gh release create v$(make version) \
  --title "v$(make version)" \
  --notes "Description of changes"
```

## Quick Reference

| Task | Command |
|------|---------|
| Check current version | `make version` |
| Bump patch | `make bump-patch` |
| Bump minor | `make bump-minor` |
| Bump major | `make bump-major` |
| Set exact version | `make set-version V=1.2.3` |
| Show full info | `make info` |
| Tag and commit release | `make release` |
