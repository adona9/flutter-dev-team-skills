---
name: git-workflow
description: >
  Git workflow and contribution rules for app developers. Load this skill
  whenever the user is about to commit, push, create a branch, open a PR,
  review changes, squash commits, or ask about release or changelog process.
  Triggers on: "commit", "push", "branch", "PR", "pull request", "merge",
  "squash", "rebase", "release", "changelog", "dependabot", "CHANGELOG".
  This skill is not Flutter-specific and applies to any project.
---

# Git Workflow

Standard contribution rules for all app developers on this project.
These rules are enforced by the `pr-review` skill and reflected in `CONTRIBUTING.md`.

---

## Commit Messages — Conventional Commits

All commits must follow the [Conventional Commits](https://www.conventionalcommits.org/) spec.

```
<type>(<scope>): <short summary>

[optional body]

[optional footer(s)]
```

**Allowed types:**

| Type | When to use |
|---|---|
| `feat` | New feature visible to users |
| `fix` | Bug fix |
| `refactor` | Code change with no behavior change |
| `test` | Adding or fixing tests only |
| `docs` | Documentation only |
| `chore` | Build, tooling, dependency updates |
| `perf` | Performance improvement |
| `ci` | CI/CD pipeline changes |
| `revert` | Reverting a previous commit |

**Rules:**
- Summary line: imperative mood, lowercase, no period, ≤ 72 characters
- `feat` and `fix` types trigger a new entry in `CHANGELOG.md` via release-please
- Breaking changes: add `!` after type (`feat!:`) and a `BREAKING CHANGE:` footer
- Never use `git commit -m` for multi-line messages — use `--edit` or a HEREDOC

**Examples:**
```
feat(auth): add biometric login support
fix(feed): prevent duplicate posts on pull-to-refresh
chore(deps): update flutter to 3.24.0
feat!: remove legacy v1 API support

BREAKING CHANGE: v1 endpoints removed; clients must migrate to v2
```

---

## Branch Names

Branch names must use a conventional commit prefix, followed by a short slug.

```
<type>/<short-slug>
```

**Examples:**
```
feat/biometric-login
fix/feed-duplicate-posts
chore/update-flutter-3-24
refactor/auth-repository
```

**Rules:**
- Use hyphens, not underscores or camelCase
- Keep it short and descriptive — the PR title carries the full context
- Never work directly on `main` — always branch

---

## Pull Request Workflow

### 1. Create a branch
```bash
git checkout -b feat/my-feature
```

### 2. Make changes and commit
Follow conventional commit rules for every commit.

### 3. Push and open a PR
```bash
git push -u origin feat/my-feature
```
PR title must follow conventional commit format (same as a commit message).
It becomes the squash commit message, so make it count.

### 4. Run pr-review before requesting human review
Ask Claude to run the `pr-review` skill on your changes.
The skill fans out into 4 check layers and produces a PASS / BLOCK verdict.
Do not request human review until pr-review passes.

### 5. Push fixes
Address feedback with additional commits on the same branch.
Review-cycle commits must still be valid conventional commits; the bar for scope and
summary quality is lower, but the format is not (`fix: address review feedback` is fine,
`wip: trying a thing` is not).

### 6. Merge — squash or rebase only
Once pr-review passes and human review approves:
- **Squash merge** (default) — produces one clean commit on `main`; use for most branches
- **Rebase merge** (opt-in) — every branch commit lands on `main` individually; only use
  this when every commit is already clean. **Requires a `git rebase -i` cleanup pass before
  merging** — remove WIP commits, fixups, and duplicate messages first.
- **Never use a regular merge commit** — merge commits pollute the history

**Every commit that lands on `main` must be a valid conventional commit.**

---

## Commit History Rules

- `main` must have a linear, readable history — no merge bubbles
- Squash noisy branches before merging
- Do not amend or force-push commits that have already been reviewed
- `git rebase -i` is fine for local cleanup before opening a PR, and required before a rebase merge

---

## Changelog — release-please

`CHANGELOG.md` is **never edited by hand**. It is generated automatically by
[release-please](https://github.com/googleapis/release-please).

**How it works:**
- release-please watches commits on `main` for `feat:` and `fix:` types
- It opens a "Release PR" that bumps the version and updates `CHANGELOG.md`
- Merging the Release PR creates the release and tag
- If the Release PR goes stale (more commits landed before it was merged), close and reopen it — release-please regenerates it cleanly

**Rules:**
- Do not create version tags manually
- Do not edit `CHANGELOG.md` directly
- `feat` → minor version bump, `fix` → patch bump, `feat!` / `BREAKING CHANGE` → major bump
- `perf`, `refactor`, `ci`, `chore` do **not** trigger a release — if a change is user-visible, use `fix` or `feat` instead

---

## Dependency Updates — Dependabot

[Dependabot](https://docs.github.com/en/code-security/dependabot) creates PRs
to keep packages up to date automatically.

Dependabot is configured (see `templates/.github/dependabot.yml`) to prefix PR titles and
commit messages with `chore(deps):`, making them valid conventional commits that land cleanly on `main`.

**Rules:**
- Dependabot PRs are reviewed by the `pr-review` skill, not humans
- If pr-review passes, merge without ceremony
- If pr-review blocks, investigate before merging — a failing check on a dep update is a signal
- Do not let Dependabot PRs accumulate — stale updates compound into conflicts
- `chore(deps):` commits do not trigger a release-please release — that is intentional

---

## Quick Reference

```
branch:   <type>/<slug>              e.g. feat/dark-mode
commit:   <type>(<scope>): <summary> e.g. feat(ui): add dark mode toggle
PR title: same format as commit      becomes the squash commit message
merge:    squash or rebase           never a merge commit
changelog: release-please only       never edit by hand
deps:     dependabot + pr-review     no manual version bumps
```
