# Git Hooks Setup

Wire `pr_review.sh` into git so it runs automatically before every push.
You never have to remember to run it manually.

---

## Install the pre-push hook

From your project root:

```bash
# Create the hook
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash
# Pre-push hook — runs PR review before every git push
# To bypass in emergencies: git push --no-verify

echo "Running PR review before push..."
bash "${CLAUDE_PLUGIN_ROOT}/pr-review/scripts/pr_review.sh"
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Push blocked — fix review issues above, then push again."
  echo "Emergency bypass: git push --no-verify (use sparingly)"
fi

exit $EXIT_CODE
EOF

# Make it executable
chmod +x .git/hooks/pre-push
```

Test it:
```bash
git push --dry-run origin main
# Should run the full review before attempting the push
```

---

## Install the pre-commit hook (quick check only)

For a fast sanity check on every commit (layers 1-2 only, ~5 seconds):

```bash
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook — quick static + architecture check only
# Full coverage + security runs on pre-push

# Only run on staged Dart files
STAGED=$(git diff --cached --name-only | grep "\.dart$" || true)
[ -z "$STAGED" ] && exit 0

echo "Quick review (static + architecture)..."
bash "${CLAUDE_PLUGIN_ROOT}/pr-review/scripts/pr_review.sh" --quick
EOF

chmod +x .git/hooks/pre-commit
```

---

## Hook summary

| Hook | When | Layers | Speed |
|---|---|---|---|
| `pre-commit` | Every `git commit` | 1-2 (static + arch) | ~5s |
| `pre-push` | Every `git push` | 1-4 + adversarial | ~30-60s |

---

## Sharing hooks with yourself across machines

Git hooks aren't committed to the repo by default. To make them portable:

```bash
# Store hooks in a committed directory
mkdir -p .githooks
cp .git/hooks/pre-commit .githooks/
cp .git/hooks/pre-push .githooks/
git add .githooks/
git commit -m "chore: add git hooks for pr-review"

# On any new machine, after cloning:
git config core.hooksPath .githooks
chmod +x .githooks/*
```

Add this to your `README.md` setup section so you don't forget:
```markdown
## Setup
After cloning:
```bash
git config core.hooksPath .githooks
chmod +x .githooks/*
bash "${CLAUDE_PLUGIN_ROOT}/flutter-context/scripts/mac_setup.sh" <mac-ip> <mac-user>
```
```
