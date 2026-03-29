# Contributing

This document describes the development workflow for contributors to this project.
It is written for app developers, not the general public.

---

## Branches

Always work in a branch. Never commit directly to `main`.

Branch names follow conventional commit prefixes:

```
<type>/<short-slug>
```

| Type | When to use |
|---|---|
| `feat/` | New feature |
| `fix/` | Bug fix |
| `refactor/` | Code change, no behavior change |
| `chore/` | Tooling, deps, build |
| `test/` | Tests only |
| `docs/` | Documentation only |

Examples:
```
feat/biometric-login
fix/feed-duplicate-posts
chore/update-flutter-3-24
```

---

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>
```

- Imperative mood, lowercase, no trailing period
- Summary ≤ 72 characters
- `feat` and `fix` appear in the changelog — write them for a reader, not a reviewer
- Breaking changes: use `feat!:` or `fix!:` and add a `BREAKING CHANGE:` footer

```
feat(auth): add biometric login support
fix(feed): prevent duplicate posts on pull-to-refresh
chore(deps): update flutter to 3.24.0
feat!: remove legacy v1 API endpoints

BREAKING CHANGE: v1 endpoints removed; migrate to v2
```

---

## Pull Requests

### Opening a PR

1. Push your branch: `git push -u origin feat/my-feature`
2. Open a PR with a title in conventional commit format — it becomes the squash commit message on `main`
3. The description should explain **why**, not just what changed

### Before requesting review

Run the `pr-review` skill with Claude Code and fix any issues it reports.
Do not request human review until pr-review returns a **PASS** verdict.

### During review

Push additional commits to address feedback. Review-cycle commits must still be valid
conventional commits — the bar for scope and summary quality is lower, but the format
is not. `fix: address review feedback` is fine; `wip: trying a thing` is not.

### Merging

Once pr-review passes and the PR is approved:

- **Squash merge** (default) — one clean commit lands on `main`; use for most branches
- **Rebase merge** (opt-in) — every branch commit lands individually; only use this when
  every commit is already clean. Run `git rebase -i` to remove fixups and WIP commits
  before merging.

**Never use a regular merge commit.** `main` must have a linear history.

Every commit that lands on `main` must be a valid conventional commit.

---

## Changelog

`CHANGELOG.md` is generated automatically by [release-please](https://github.com/googleapis/release-please).
**Do not edit it by hand.**

- `feat:` commits → minor version bump
- `fix:` commits → patch version bump
- `feat!:` / `BREAKING CHANGE:` → major version bump
- `perf`, `refactor`, `ci`, `chore` do **not** trigger a release — use `fix` or `feat` for anything user-visible

release-please opens a "Release PR" when there are releasable commits on `main`.
Merging it creates the release and git tag. If the Release PR goes stale, close and
reopen it — release-please will regenerate it.

Do not create version tags manually.

---

## Dependency Updates

[Dependabot](https://docs.github.com/en/code-security/dependabot) keeps packages
up to date by opening PRs automatically. It is configured to use `chore(deps):` prefixes
so its commits are valid conventional commits. The `pr-review` skill is the designated reviewer.

- If pr-review passes → merge without ceremony
- If pr-review blocks → investigate before merging
- Do not let Dependabot PRs accumulate — stale updates compound into conflicts
- `chore(deps):` commits do not trigger a release — that is intentional

---

## Quick Reference

| What | Rule |
|---|---|
| Branch name | `<type>/<slug>` |
| Commit message | `<type>(<scope>): <summary>` |
| PR title | Same format as commit message |
| Merge strategy | Squash or rebase — no merge commits |
| Review gate | pr-review must PASS before human review |
| Changelog | release-please only, never edit by hand |
| Dependency PRs | Dependabot + pr-review, no manual bumps |
