---
name: flutter-context
description: >
  Foundation skill for all Flutter app development tasks. ALWAYS load this skill
  at the start of any Flutter, Dart, widget, screen, provider, riverpod, go_router,
  or mobile app session — including creating files, writing features, designing
  architecture, fixing bugs, running tests, or preparing for App Store / Play Store
  submission. Also trigger when the user mentions "app", "widget", "screen",
  "build", "deploy", "iPhone", "Android", "pubspec", "dart", or "flutter".
  This skill establishes the project constitution that all other Flutter skills
  depend on. ALWAYS load this before flutter-architect, ui-builder, test-writer,
  or pr-review skills.
---

# Flutter Context — Project Constitution

Single source of truth for how this project is built and deployed.
All other skills inherit these rules. In case of conflict, this skill wins.

---

## Project Snapshot

| Property | Value |
|---|---|
| Framework | Flutter (latest stable) |
| Language | Dart |
| State Management | Riverpod (flutter_riverpod) |
| Architecture | Repository pattern (Clean Architecture layers) |
| Navigation | go_router |
| Primary Target | iOS (iPhone) |
| Secondary Target | Android (emulator for local dev) |
| Dev Machine | Ubuntu (Linux) |
| Build Machine | Mac Mini on LAN (SSH access) |
| Min iOS Version | 17.0 |
| Min Android SDK | 23 |

---

## Directory Layout

```
my_app/
├── lib/
│   ├── main.dart                    # Entry point — bootstrap only, no logic
│   ├── app.dart                     # MaterialApp / CupertinoApp + router setup
│   ├── core/
│   │   ├── network/
│   │   │   ├── api_client.dart      # Dio/http wrapper
│   │   │   └── api_endpoints.dart   # All endpoint constants
│   │   ├── error/
│   │   │   ├── failures.dart        # Sealed failure classes
│   │   │   └── exceptions.dart      # Network/cache exceptions
│   │   ├── providers/
│   │   │   └── core_providers.dart  # Shared infrastructure providers
│   │   └── utils/
│   ├── features/
│   │   └── feature_name/
│   │       ├── data/
│   │       │   ├── datasources/     # Remote + local data sources
│   │       │   ├── models/          # JSON-serializable models (freezed)
│   │       │   └── repositories/    # Repository implementations
│   │       ├── domain/
│   │       │   ├── entities/        # Pure Dart classes, no Flutter imports
│   │       │   ├── repositories/    # Abstract repository interfaces
│   │       │   └── usecases/        # Single-responsibility use cases
│   │       └── presentation/
│   │           ├── providers/       # Riverpod providers for this feature
│   │           ├── screens/         # Full screens (route destinations)
│   │           └── widgets/         # Feature-local widgets
│   ├── design_system/
│   │   ├── tokens/
│   │   │   ├── colors.dart
│   │   │   ├── typography.dart
│   │   │   └── spacing.dart
│   │   └── components/              # Shared reusable widgets
│   └── router/
│       ├── app_router.dart          # go_router configuration
│       └── routes.dart              # Route name constants
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
├── scripts/
│   ├── build_ios.sh                 # Triggers Mac Mini build remotely
│   ├── deploy_to_device.sh          # Installs IPA to iPhone via Mac Mini
│   └── mac_setup.sh                 # One-time Mac Mini setup script
├── pubspec.yaml
└── analysis_options.yaml
```

**Rule**: No business logic in presentation layer. No Flutter imports in domain layer.

---

## Architecture Layers

### Data Layer
- Models use `freezed` for immutability + `json_serializable` for JSON
- Two datasource types per feature: `RemoteDataSource` + `LocalDataSource`
- Repository implementations live here, fulfill domain interfaces

### Domain Layer
- Pure Dart — zero Flutter/package imports except `equatable`
- Entities are the app's truth, models are transport format
- Use cases: one public method, one responsibility

### Presentation Layer
- Riverpod providers connect domain to UI
- Screens are route destinations — kept thin
- Widgets are composable, reusable pieces

---

## Riverpod Patterns

### Provider hierarchy
```dart
// 1. Infrastructure (core_providers.dart)
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// 2. Data source
final postRemoteDataSourceProvider = Provider<PostRemoteDataSource>(
  (ref) => PostRemoteDataSourceImpl(ref.watch(apiClientProvider)),
);

// 3. Repository
final postRepositoryProvider = Provider<PostRepository>(
  (ref) => PostRepositoryImpl(ref.watch(postRemoteDataSourceProvider)),
);

// 4. Use case
final getPostFeedProvider = Provider<GetPostFeed>(
  (ref) => GetPostFeed(ref.watch(postRepositoryProvider)),
);

// 5. Notifier (screen state)
@riverpod
class FeedNotifier extends _$FeedNotifier {
  @override
  Future<List<Post>> build() async {
    return ref.watch(getPostFeedProvider).call(cursor: null);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(getPostFeedProvider).call(cursor: null),
    );
  }
}
```

### State handling in widgets — always handle all three states
```dart
class FeedScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedNotifierProvider);

    return feedAsync.when(
      loading: () => const FeedSkeleton(),       // skeleton, not spinner
      error: (err, _) => ErrorView(              // never swallow errors
        message: err.toString(),
        onRetry: () => ref.invalidate(feedNotifierProvider),
      ),
      data: (posts) => posts.isEmpty
          ? const EmptyFeedView()                // explicit empty state
          : FeedList(posts: posts),
    );
  }
}
```

**Rule**: Never use `.value` without handling `.loading` and `.error`. No exceptions.

---

## go_router Configuration

```dart
// router/routes.dart
abstract class Routes {
  static const feed        = '/feed';
  static const discover    = '/discover';
  static const profile     = '/profile';
  static const postDetail  = '/post/:postId';
  static const userProfile = '/user/:userId';
  static const comments    = '/post/:postId/comments';
}

// router/app_router.dart
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.feed,
    routes: [
      StatefulShellRoute.indexedStack(        // bottom nav tabs
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.feed, builder: (_, __) => const FeedScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.discover, builder: (_, __) => const DiscoverScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.profile,
              builder: (_, __) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (_, __) => const EditProfileScreen(),
                ),
              ],
            ),
          ]),
        ],
      ),
      // Modal routes (outside shell — no bottom nav)
      GoRoute(
        path: Routes.postDetail,
        builder: (context, state) => PostDetailScreen(
          postId: state.pathParameters['postId']!,
        ),
      ),
    ],
  );
});
```

**Rules:**
- Route name constants live in `Routes` — never hardcode strings
- Deep links use path parameters, not query parameters for IDs
- Modal screens (sheets, full-screen) defined outside `StatefulShellRoute`

---

## Approved Packages

Agent must NOT add packages outside this list without asking the user first.

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management |
| `riverpod_annotation` | Code generation for providers |
| `go_router` | Navigation |
| `freezed` | Immutable models |
| `json_serializable` | JSON serialization |
| `dio` | HTTP client |
| `cached_network_image` | Image loading + caching |
| `shared_preferences` | Simple local storage |
| `flutter_secure_storage` | Sensitive data (tokens) |
| `equatable` | Value equality in domain layer |
| `drift` | Local relational database (SQLite ORM) |
| `sqlite3_flutter_libs` | SQLite native binaries (required by drift) |
| `path_provider` | Platform-specific file/directory paths |
| `path` | Path string manipulation |

**Before adding any new package:**
1. Confirm it's not already achievable with an approved package
2. Check pub.dev score ≥ 130, Flutter Favorite or high popularity
3. Ask user: "I'd like to add `[package]` for `[reason]`. Pub score: [n]. OK?"
4. Update this list after approval

---

## Quality Gate 1: Widget + Integration Tests

```dart
// Widget test pattern
testWidgets('FeedScreen shows posts when loaded', (tester) async {
  final container = ProviderContainer(overrides: [
    feedNotifierProvider.overrideWith(() => MockFeedNotifier()),
  ]);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: FeedScreen()),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(PostCard), findsWidgets);
});
```

**Rules:**
- Every screen has a widget test covering: loading state, data state, empty state, error state
- Integration tests use `flutter_test` with mock providers — never hit real network
- Use `MockNotifier` pattern to inject controlled state

---

## Quality Gate 2: App Store + Play Store Compliance

Run before every release build:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/flutter-context/scripts/check_compliance.sh"
```

**iOS non-negotiables:**
- `PrivacyInfo.xcprivacy` present and current
- All `NSUsageDescription` keys in `Info.plist` for APIs used
- Version + build number bumped in `pubspec.yaml` before every TestFlight build
- No hardcoded API keys or secrets anywhere in Dart code

**Android non-negotiables:**
- `versionCode` and `versionName` bumped in `build.gradle`
- All permissions declared in `AndroidManifest.xml` with justification comment
- `minSdkVersion 23` — do not lower without explicit approval

---

## Build Pipeline: Ubuntu → Mac Mini → iPhone

### One-time Mac Mini setup
```bash
# Run once from Ubuntu to configure the Mac Mini
bash "${CLAUDE_PLUGIN_ROOT}/flutter-context/scripts/mac_setup.sh" <mac-mini-ip> <mac-username>
```
See `references/mac-setup-guide.md` for what this installs.

### Daily build workflow
```bash
# From Ubuntu — builds iOS on Mac Mini and installs to connected iPhone
bash "${CLAUDE_PLUGIN_ROOT}/flutter-context/scripts/build_ios.sh"

# With options
bash "${CLAUDE_PLUGIN_ROOT}/flutter-context/scripts/build_ios.sh" --release          # Release build (for TestFlight)
bash "${CLAUDE_PLUGIN_ROOT}/flutter-context/scripts/build_ios.sh" --no-install       # Build only, don't install
bash "${CLAUDE_PLUGIN_ROOT}/flutter-context/scripts/build_ios.sh" --ip 192.168.1.x  # Override Mac Mini IP
```

Mac Mini IP and username stored in `~/.flutter_build_config` (never committed).

---

## What the Agent Should NOT Decide

1. Directory structure — locked above
2. Layer boundaries — no Flutter imports in domain, ever
3. Navigation pattern — go_router + StatefulShellRoute, always
4. State handling — always handle loading/error/data, never `.value` shortcuts
5. Package additions — always ask first
6. Route strings — always use `Routes` constants, never hardcode
7. Build pipeline — always use `build_ios.sh`, never manual steps

## What the Agent SHOULD Decide

- Feature decomposition into sub-screens and sub-widgets
- Whether a use case is needed or repository call is sufficient
- Widget extraction threshold (when a widget block becomes its own class)
- Skeleton/shimmer design for loading states
- Error message copy and retry UX
- Cache invalidation strategy per feature

---

## Session Startup Checklist

Agent silently verifies at session start:
1. Does this task touch presentation? → Apply Riverpod `.when()` pattern
2. Does this task touch domain? → No Flutter imports allowed
3. Does this task add a new route? → Add to `Routes` constants + router
4. Does this task need a new package? → Ask before adding
5. Is this a build/deploy task? → Use `build_ios.sh`, not manual flutter commands
6. Is this pre-release? → Run `check_compliance.sh` first

---

## Reference Files

- `references/mac-setup-guide.md` — Mac Mini one-time setup walkthrough
- `references/riverpod-patterns.md` — extended Riverpod patterns for social features
- `references/social-patterns.md` — feed, like, follow, pagination patterns in Flutter
- `references/testing-patterns.md` — widget and integration test templates
