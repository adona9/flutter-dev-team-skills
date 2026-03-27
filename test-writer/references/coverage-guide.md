# Coverage Guide

What counts toward coverage, what's excluded, how to read the report,
and how to run the coverage gate.

---

## Running Coverage

```bash
# Full check (run from project root)
bash "${CLAUDE_PLUGIN_ROOT}/test-writer/scripts/check_coverage.sh"

# With custom threshold
bash "${CLAUDE_PLUGIN_ROOT}/test-writer/scripts/check_coverage.sh" --threshold 90

# Generate HTML report to browse uncovered lines
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html   # macOS / via SSH to Mac Mini
```

---

## Threshold

**80% line coverage** — hard gate. Build fails below this.

This is the minimum. New features should target 90%+. The 80% floor exists to
prevent the codebase from drifting into an untested state over time.

---

## What Counts

Coverage is measured on **line hits** — a line is covered if it was executed
during at least one test run.

Files that count:
- All `.dart` files under `lib/` that are not in the exclusion list below

---

## Exclusions (automatically filtered)

The coverage script excludes these from the denominator:

| Pattern | Reason |
|---|---|
| `*.g.dart` | `json_serializable` generated — not hand-written logic |
| `*.freezed.dart` | `freezed` generated — not hand-written logic |
| `*.mocks.dart` | `mockito`/`mocktail` generated |
| `lib/main.dart` | Bootstrap only — no testable logic |
| `lib/app.dart` | Theme + router config — no testable logic |

To add more exclusions, edit the `EXCLUDE_PATTERNS` array in `check_coverage.sh`.

---

## Reading the lcov Report

After `flutter test --coverage`, open `coverage/html/index.html`.

| Color | Meaning |
|---|---|
| Green | Line was executed during tests |
| Red | Line was never executed |
| Yellow | Branch not fully covered (both true/false paths not taken) |

Focus red lines on:
1. Error paths (catch blocks, error state branches)
2. Edge cases (null checks, empty list handling)
3. Business logic in use cases and notifiers

---

## Common Coverage Gaps and Fixes

**Error paths not covered**
```dart
// Test the failure case explicitly:
when(() => mockRepo.getData()).thenThrow(Exception('network'));
await expectLater(
  () => container.read(notifierProvider.notifier).load(),
  throwsException,
);
```

**Empty state not covered**
```dart
// Add a test with an empty list:
when(() => mockRepo.getData()).thenAnswer((_) async => []);
await container.read(notifierProvider.future);
expect(container.read(notifierProvider).value, isEmpty);
```

**Optimistic revert not covered**
```dart
// Test the revert path:
when(() => mockRepo.toggleLike(any())).thenThrow(Exception());
final before = container.read(notifierProvider).value!;
await expectLater(() => notifier.toggleLike('id'), throwsException);
expect(container.read(notifierProvider).value, equals(before));
```

---

## CI Integration

The coverage gate runs automatically as Layer 3 of `pr_review.sh`. It also
runs as part of `build_ios.sh` before triggering the iOS build — you cannot
build with coverage below threshold.

To run just the coverage check in CI:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/test-writer/scripts/check_coverage.sh"
```
