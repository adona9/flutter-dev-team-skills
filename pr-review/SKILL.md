---
name: pr-review
description: >
  Use this skill before every git commit, push, or merge. Triggers on: "review
  my code", "check my PR", "pre-merge check", "is this ready to merge", "review
  these changes", "check my diff", "what did I break", "ready to push", "commit
  review", or whenever the user is about to commit or push code. Also trigger
  automatically after flutter-architect or ui-builder generates new files — those
  outputs should always pass review before committing. ALWAYS load flutter-context
  first. This skill fans out into 4 independent review layers and produces a
  single pass/fail verdict.
---

# PR Review

Automated pre-merge quality gate. Replaces line-by-line human review with
4 deterministic + 1 adversarial check layer. Produces a structured report
with a single PASS / BLOCK verdict.

**Depends on**: `flutter-context`, `test-writer` (coverage gate is Layer 3)

**Philosophy** (from Latent Space): humans review *intent* — specs, acceptance
criteria, architecture decisions. Agents review *implementation* — correctness,
consistency, coverage, safety. This skill is the agent layer.

---

## When to Run

```bash
bash "${CLAUDE_PLUGIN_ROOT}/pr-review/scripts/pr_review.sh"              # full review of all changed files
bash "${CLAUDE_PLUGIN_ROOT}/pr-review/scripts/pr_review.sh" --quick      # layers 1-2 only (fast, pre-commit)
bash "${CLAUDE_PLUGIN_ROOT}/pr-review/scripts/pr_review.sh" --file path  # review a single file
```

Run automatically via git hook — see `references/git-hooks-setup.md`.

---

## The 4 Review Layers

Each layer is independent. All must pass for a PASS verdict.
Any BLOCK in any layer = overall BLOCK.

```
Layer 1: Static Analysis     — dart analyze, dart format, custom lints
Layer 2: Architecture Guard  — layer boundaries, naming, forbidden patterns
Layer 3: Coverage Gate       — 80% line coverage (delegates to test-writer)
Layer 4: Security Scan       — hardcoded secrets, dangerous API usage
```

The agent acts as **Layer 5: Adversarial Reviewer** — reads the diff after
all scripts pass and attempts to find what the scripts missed.

---

## Layer 1: Static Analysis (deterministic)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/pr-review/scripts/layer1_static.sh"
```

Checks:
- `dart analyze` — zero issues, zero warnings (info allowed)
- `dart format --set-exit-if-changed` — all files formatted
- Unused imports scan
- Dead code detection

**Rule**: `dart analyze` must return zero errors AND zero warnings.
Info-level hints are allowed. Warnings are not.

```bash
#!/bin/bash
# scripts/layer1_static.sh
set -e
PASS=0; FAIL=0; ERRORS=()

echo "[ Layer 1: Static Analysis ]"

# dart analyze
echo "  Running dart analyze..."
if dart analyze --fatal-warnings 2>&1 | grep -q "No issues found"; then
  echo "  ✅ dart analyze — clean"
  PASS=$((PASS+1))
else
  OUTPUT=$(dart analyze --fatal-warnings 2>&1)
  echo "  ❌ dart analyze — issues found"
  echo "$OUTPUT" | grep -E "error|warning" | head -20
  ERRORS+=("dart analyze failed")
  FAIL=$((FAIL+1))
fi

# dart format
echo "  Checking dart format..."
if dart format --set-exit-if-changed . 2>&1 | grep -q "Formatted"; then
  echo "  ❌ dart format — unformatted files detected"
  echo "  Run: dart format ."
  ERRORS+=("Unformatted files — run dart format .")
  FAIL=$((FAIL+1))
else
  echo "  ✅ dart format — all files formatted"
  PASS=$((PASS+1))
fi

[ $FAIL -gt 0 ] && exit 1 || exit 0
```

---

## Layer 2: Architecture Guard (deterministic)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/pr-review/scripts/layer2_architecture.sh" [changed_files...]
```

Checks every changed `.dart` file for:

### Forbidden patterns (instant BLOCK)

| Pattern | Rule | Why |
|---|---|---|
| Flutter import in `domain/` | Domain must be pure Dart | Layer boundary violation |
| `http.get(` / `Dio(` in presentation | No direct API calls in UI layer | Bypasses repository |
| `SharedPreferences` in domain | No persistence in domain | Layer boundary violation |
| Hardcoded route strings | Must use `Routes.*` constants | Breaks deep links |
| `setState(` in `ConsumerWidget` | Mixing paradigms | Use Riverpod state |
| `print(` in non-test files | No debug prints in production | Log leakage |
| `.value` on `AsyncValue` without guard | Unsafe unwrap | Runtime crash |
| Color hex literals in widgets | Must use `AppColors.*` | Token violation |
| Magic spacing numbers (`padding: EdgeInsets.all(16)`) | Must use `AppSpacing.*` | Token violation |

### Naming violations (BLOCK)

| File location | Must match |
|---|---|
| `presentation/screens/` | `*Screen` suffix |
| `presentation/providers/` | `*Provider` or `*Notifier` suffix |
| `domain/entities/` | No suffix (plain noun) |
| `domain/repositories/` | `*Repository` suffix (abstract) |
| `domain/usecases/` | Verb + Noun pattern (`GetUserProfile`, `CreatePost`) |
| `data/models/` | `*Model` suffix |
| `data/datasources/` | `*DataSource` suffix |
| `data/repositories/` | `*RepositoryImpl` suffix |

```bash
#!/bin/bash
# scripts/layer2_architecture.sh
FILES=("$@")
[ ${#FILES[@]} -eq 0 ] && FILES=($(git diff --name-only HEAD | grep "\.dart$"))

FAIL=0; ERRORS=()

echo "[ Layer 2: Architecture Guard ]"
echo "  Checking ${#FILES[@]} file(s)..."

for file in "${FILES[@]}"; do
  [ ! -f "$file" ] && continue

  # Layer boundary: no Flutter imports in domain
  if echo "$file" | grep -q "domain/" && grep -q "package:flutter" "$file"; then
    echo "  ❌ $file — Flutter import in domain layer"
    ERRORS+=("$file: domain layer must be pure Dart")
    FAIL=$((FAIL+1))
  fi

  # No direct API calls in presentation
  if echo "$file" | grep -q "presentation/" && grep -qE "Dio\(\)|http\.get\(" "$file"; then
    echo "  ❌ $file — direct API call in presentation layer"
    ERRORS+=("$file: use repository, not direct API calls")
    FAIL=$((FAIL+1))
  fi

  # No print statements outside tests
  if ! echo "$file" | grep -q "test/" && grep -qE "^\s+print\(" "$file"; then
    echo "  ❌ $file — print() found (use logger or remove)"
    ERRORS+=("$file: remove print() statements")
    FAIL=$((FAIL+1))
  fi

  # No hardcoded route strings
  if grep -qE "context\.go\(['\"]/" "$file" || grep -qE "GoRouter.*path:\s*['\"]/" "$file"; then
    # Check it's not in routes.dart itself
    if ! echo "$file" | grep -q "routes.dart"; then
      echo "  ⚠️  $file — possible hardcoded route string (use Routes.*)"
    fi
  fi

  # No hardcoded colors in widgets
  if echo "$file" | grep -qE "presentation/|design_system/" && \
     grep -qE "Color\(0x[Ff][Ff]" "$file"; then
    echo "  ❌ $file — hardcoded Color() value (use AppColors.*)"
    ERRORS+=("$file: use AppColors tokens, not hardcoded hex")
    FAIL=$((FAIL+1))
  fi

  # Unsafe AsyncValue unwrap
  if grep -qE "\.value\b" "$file" && ! echo "$file" | grep -q "test/"; then
    if ! grep -q "valueOrNull" "$file"; then
      echo "  ⚠️  $file — .value on AsyncValue may throw; prefer .valueOrNull or .when()"
    fi
  fi

  # setState in ConsumerWidget
  if grep -q "ConsumerWidget\|ConsumerStatefulWidget" "$file" && \
     grep -q "setState(" "$file"; then
    echo "  ❌ $file — setState() in ConsumerWidget (use Riverpod state)"
    ERRORS+=("$file: remove setState, use Riverpod")
    FAIL=$((FAIL+1))
  fi

  [ $FAIL -eq 0 ] && echo "  ✅ $file"
done

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "  ${#ERRORS[@]} architecture violation(s):"
  for e in "${ERRORS[@]}"; do echo "    • $e"; done
  exit 1
fi

echo "  ✅ Architecture guard passed"
exit 0
```

---

## Layer 3: Coverage Gate (deterministic)

Delegates directly to `test-writer`'s script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/test-writer/scripts/check_coverage.sh" --threshold 80
```

Or if installed locally:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/pr-review/scripts/layer3_coverage.sh"
```

A new feature with no tests is an automatic BLOCK.
The coverage script already handles this — new uncovered files lower the
percentage below 80%.

---

## Layer 4: Security Scan (deterministic)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/pr-review/scripts/layer4_security.sh"
```

```bash
#!/bin/bash
# scripts/layer4_security.sh
FAIL=0; ERRORS=(); WARNINGS=()

echo "[ Layer 4: Security Scan ]"

# Hardcoded secrets
SECRET_PATTERNS=(
  "api_key\s*=\s*['\"]"
  "apiKey\s*=\s*['\"]"
  "API_KEY\s*=\s*['\"]"
  "secret\s*=\s*['\"]"
  "password\s*=\s*['\"]"
  "bearer\s+[A-Za-z0-9\-_]{20}"
  "sk-[A-Za-z0-9]{20}"
)

for pattern in "${SECRET_PATTERNS[@]}"; do
  HITS=$(grep -rn --include="*.dart" -iE "$pattern" lib/ 2>/dev/null | grep -v "_test.dart" || true)
  if [ -n "$HITS" ]; then
    echo "  ❌ Possible hardcoded secret:"
    echo "$HITS" | head -5
    ERRORS+=("Hardcoded secret pattern: $pattern")
    FAIL=$((FAIL+1))
  fi
done

# http:// URLs (should be https://)
HTTP_HITS=$(grep -rn --include="*.dart" "http://" lib/ 2>/dev/null | \
  grep -v "localhost\|127.0.0.1\|//localhost" || true)
if [ -n "$HTTP_HITS" ]; then
  echo "  ⚠️  Non-HTTPS URLs found (use https://):"
  echo "$HTTP_HITS" | head -5
  WARNINGS+=("Non-HTTPS URLs detected")
fi

# Dangerous permissions check (iOS Info.plist)
if [ -f "ios/Runner/Info.plist" ]; then
  for key in NSLocationAlwaysUsageDescription NSLocationAlwaysAndWhenInUseUsageDescription; do
    if grep -q "$key" ios/Runner/Info.plist; then
      echo "  ⚠️  $key in Info.plist — 'always' location requires strong justification"
      WARNINGS+=("Always-on location permission detected")
    fi
  done
fi

# flutter_secure_storage used for tokens (good)
if grep -rq "SharedPreferences" lib/ 2>/dev/null; then
  if grep -rq "token\|auth\|session\|password" lib/ 2>/dev/null | \
     grep -q "SharedPreferences"; then
    echo "  ❌ Auth token stored in SharedPreferences (use flutter_secure_storage)"
    ERRORS+=("Sensitive data in SharedPreferences")
    FAIL=$((FAIL+1))
  fi
fi

[ $FAIL -gt 0 ] && exit 1 || exit 0
```

---

## Layer 5: Adversarial Review (agent)

After all 4 scripts pass, the agent reads the diff and attempts to find
what the scripts missed. This is the human-judgment layer — but done by
a second agent instance with a reviewer mindset, not the implementer.

**Agent reviewer prompt** (used internally):
```
You are an adversarial code reviewer. Your job is to find problems the
implementer missed. You are NOT trying to be helpful — you are trying to
BLOCK this PR if there is any legitimate reason to.

Review the following diff with these questions:
1. Does the implementation actually solve the stated requirement?
2. Are there edge cases not handled (null, empty list, network timeout,
   user not logged in, rapid taps, background/foreground transition)?
3. Does any new Riverpod provider risk being disposed while in use?
4. Are optimistic updates reversible on ALL error paths?
5. Is any new widget missing a loading state, error state, or empty state?
6. Does any new route lack a corresponding deep link handler?
7. Are there race conditions (multiple async calls, no guard)?
8. Would this work correctly if the user has slow network (3G)?
9. Is there any state that persists when it shouldn't across sessions?
10. Are there any accessibility regressions (missing semanticLabel, tooltip)?

For each issue found: state the file, line, problem, and required fix.
If no issues found, say LGTM with one sentence explaining why you're confident.
Do NOT suggest improvements or nice-to-haves — only blockers.
```

The agent runs this review and appends results to the final report.

---

## Full Review Script

```bash
bash "${CLAUDE_PLUGIN_ROOT}/pr-review/scripts/pr_review.sh"
```

```bash
#!/bin/bash
# scripts/pr_review.sh — Full PR review orchestrator
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

QUICK=false
TARGET_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --quick) QUICK=true; shift ;;
    --file) TARGET_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

CHANGED_FILES=$(git diff --name-only HEAD | grep "\.dart$" || true)
[ -n "$TARGET_FILE" ] && CHANGED_FILES="$TARGET_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PR Review"
echo "  Files: $(echo "$CHANGED_FILES" | wc -l | tr -d ' ') changed Dart files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LAYER_RESULTS=()
OVERALL=0

run_layer() {
  local name="$1"; local script="$2"
  echo ""
  if bash "$script" $CHANGED_FILES; then
    LAYER_RESULTS+=("✅ $name")
  else
    LAYER_RESULTS+=("❌ $name — BLOCKED")
    OVERALL=1
  fi
}

run_layer "Layer 1: Static Analysis"  "${SCRIPT_DIR}/layer1_static.sh"
run_layer "Layer 2: Architecture"     "${SCRIPT_DIR}/layer2_architecture.sh"

if [ "$QUICK" = false ]; then
  run_layer "Layer 3: Coverage"       "${SCRIPT_DIR}/layer3_coverage.sh"
  run_layer "Layer 4: Security"       "${SCRIPT_DIR}/layer4_security.sh"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for result in "${LAYER_RESULTS[@]}"; do echo "  $result"; done
echo ""

if [ $OVERALL -eq 0 ] && [ "$QUICK" = false ]; then
  echo "  ⚡ Scripts passed. Running adversarial review..."
  echo "  (agent reviews diff for edge cases scripts can't catch)"
  echo ""
  # Agent layer is triggered here — the Claude Code agent reads the diff
  # and applies the adversarial reviewer prompt from the skill
  echo "  [Agent adversarial review follows]"
  git diff HEAD -- "*.dart"
fi

[ $OVERALL -eq 0 ] && echo "  ✅ PASS — ready to commit" || echo "  ❌ BLOCK — fix issues above"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
exit $OVERALL
```

---

## What the Review Should NOT Decide

- Coverage threshold — locked at 80%
- Whether to skip a layer — all 4 run every time (except `--quick` skips 3+4)
- Whether a warning is acceptable — warnings are treated as errors by `dart analyze --fatal-warnings`
- Whether a layer-2 architecture violation is "minor" — all are blockers
- Whether to pass despite a security hit — always blocks

## What the Review SHOULD Decide (adversarial layer)

- Whether edge cases are adequately handled
- Whether the implementation actually satisfies the spec
- Whether optimistic update revert paths are complete
- Whether race conditions are possible
- Whether accessibility is maintained

---

## Reference Files

- `references/git-hooks-setup.md` — install pr_review.sh as a pre-push git hook
- `references/reading-the-report.md` — how to interpret and fix each failure type
