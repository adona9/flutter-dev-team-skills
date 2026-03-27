# Reading the Review Report

How to interpret and fix every failure type.

---

## Layer 1 Failures

### `dart analyze` errors or warnings
```
❌ dart analyze — issues found
  lib/features/feed/presentation/screens/feed_screen.dart:42:5
  error: The method 'loadMore' isn't defined for type 'FeedNotifier'
```
**Fix**: The error message tells you exactly what and where. Run
`dart analyze` yourself to get the full list with clickable file paths.

### Unformatted files
```
❌ dart format — unformatted files detected
```
**Fix**: `dart format .` from project root. Done. Commit the reformatted files.

---

## Layer 2 Failures

### Flutter import in domain layer
```
❌ lib/features/profile/domain/entities/user.dart — Flutter import in domain layer
```
**Fix**: Remove the `import 'package:flutter/...'` line. Domain entities are
pure Dart. If you need `Color` or similar, move that logic to the presentation
layer or use an enum in domain that maps to a color in the widget.

### Direct API call in presentation
```
❌ lib/features/feed/presentation/screens/feed_screen.dart — direct API call
```
**Fix**: Move the API call to a `RemoteDataSource`, expose it through a
`Repository`, call it via a use case from the notifier. See
`flutter-architect/references/riverpod-wiring.md` for the full chain.

### print() in production code
```
❌ lib/core/network/api_client.dart — print() found
```
**Fix**: Delete it, or replace with a proper logger:
```dart
import 'package:flutter/foundation.dart';
debugPrint('message');  // only prints in debug mode
```

### Hardcoded Color value
```
❌ lib/features/profile/presentation/widgets/profile_header.dart — hardcoded Color()
```
**Fix**: Replace `Color(0xFF0A0A0A)` with `AppColors.background`.
Check `ui-builder`'s token file for the right constant.

### setState in ConsumerWidget
```
❌ lib/features/search/presentation/screens/search_screen.dart — setState() in ConsumerWidget
```
**Fix**: Convert local UI state to a Riverpod `StateProvider` or move it
into the notifier as a `@Published` field. Never mix setState and Riverpod.

---

## Layer 3 Failures

### Coverage below 80%
```
❌ Coverage 67% is below threshold 80%
```
**Fix**: Run `flutter test --coverage && genhtml coverage/lcov.info -o coverage/html`
then open `coverage/html/index.html`. Red lines = uncovered. Write tests for
the uncovered paths. Usually a missing error state or empty state test.

---

## Layer 4 Failures

### Hardcoded secret
```
❌ Possible hardcoded secret: api_key = "sk-abc123..."
```
**Fix**: Move to environment config. Never commit secrets. Use:
```dart
// In a gitignored .env or via dart-define at build time:
// flutter run --dart-define=API_KEY=sk-abc123
const apiKey = String.fromEnvironment('API_KEY');
```
Or use `flutter_secure_storage` for runtime secrets.

### Auth token in SharedPreferences
```
❌ Sensitive data in SharedPreferences
```
**Fix**: Replace `SharedPreferences` with `flutter_secure_storage` for any
field named token, auth, session, or password. SharedPreferences is not
encrypted and is accessible to other apps on rooted devices.

---

## Adversarial Review Findings

The adversarial layer flags things scripts can't catch. Common ones:

### "Optimistic update not fully reverted"
The revert path only fires on certain error types. Make sure `catch` is
broad enough to catch all exceptions, not just specific ones.

### "Race condition on rapid taps"
Add a guard: `if (state.isLoading) return;` at the top of async methods.

### "Missing empty state"
The `AsyncData` branch renders a list but if the list is empty, the screen
is blank. Add `when value.isEmpty` pattern — see `flutter-context` for the template.

### "No loading guard on loadMore"
```dart
// Add this check:
Future<void> loadMore() async {
  if (!_hasMore || state.isLoading || _isLoadingMore) return;  // ← guard
```

### "Works on WiFi, breaks on 3G"
Check that all `async` calls have timeouts configured on the `Dio` client,
and that the error state handles `TimeoutException` specifically.
