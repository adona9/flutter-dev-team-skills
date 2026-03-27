---
name: flutter-architect
description: >
  Use this skill when designing or scaffolding any new Flutter feature, screen,
  widget, service, repository, use case, or data model. Triggers on: "build a
  feature", "add a screen", "create a module", "scaffold", "new widget", "new
  repository", "new use case", "design the architecture for", "how should I
  structure", "add [feature name] to the app", or any request to create multiple
  related Dart files at once. Also trigger when the user describes a product
  requirement that needs translating into code structure. ALWAYS load
  flutter-context before this skill — this skill extends it, never replaces it.
---

# Flutter Architect

Translates product requirements into a concrete, file-ready Flutter feature
structure using Riverpod + Repository pattern + go_router, Material 3 UI,
for a consumer/social app.

**Depends on**: `flutter-context` — inherits all layer rules, directory layout,
naming conventions, approved packages, and build pipeline from there.

---

## Step 1: Spec Validation (NEVER skip — NEVER infer missing fields)

Run the deterministic check first:
```bash
bash scripts/validate_spec.sh
```

### Required fields for every feature
- [ ] **Feature name** — clear noun phrase (`User Profile`, `Post Creation`, `Search`)
- [ ] **Entry point** — how does the user reach this? (tab, button, deep link, push)
- [ ] **Primary user action** — the ONE thing the user does here
- [ ] **Data source** — REST endpoint + shape, or local only, or mock for now
- [ ] **Empty state** — what shows with no data
- [ ] **Error state** — what shows on failure
- [ ] **Loading state** — skeleton, shimmer, or spinner (must specify)
- [ ] **Auth required** — yes/no. If yes: what happens if session expires mid-use?

### Social-specific required fields
- [ ] **Content ownership** — who creates this content? self / others / both
- [ ] **Interaction model** — read-only, create, edit, delete, react — which apply?
- [ ] **Real-time** — does content update without user action? (yes → note polling/websocket plan)
- [ ] **Media** — does this feature involve images/video? (yes → note upload/display approach)

### Rejection triggers — STOP and ask if any apply
- Any field answered with: "TBD", "figure it out", "etc.", "and stuff", "some kind of", "various", "maybe"
- Primary action is compound ("user can view and edit and share")
  → split into separate features first
- Data source is undefined
  → cannot scaffold repository without knowing the shape
- More than 3 primary actions on one screen
  → decompose before proceeding

**Do not attempt to infer or assume. Ask exactly what is missing. One question per missing field.**

---

## Step 2: Layer Decomposition

Once spec passes, map it to the clean architecture layers.

### Decomposition template — produce this, show user, wait for confirmation

```
Feature: [Name]

Data Layer
├── model:      [FeatureName]Model          (freezed, json_serializable)
├── remote:     [FeatureName]RemoteDataSource
├── local:      [FeatureName]LocalDataSource  (only if offline needed)
└── repository: [FeatureName]RepositoryImpl  (implements domain interface)

Domain Layer
├── entity:     [FeatureName]               (pure Dart, no packages)
├── repository: [FeatureName]Repository     (abstract interface)
└── usecases:   [ActionName][FeatureName]   (one per primary action)
    e.g.        GetUserProfile
                UpdateUserProfile
                FollowUser

Presentation Layer
├── providers:  [featureName]Provider       (Riverpod notifiers)
├── screens:    [FeatureName]Screen         (route destinations)
└── widgets:    [FeatureName]Card           (feature-local composables)

Router additions
└── [new routes added to Routes constants + GoRouter config]

Shared / Core additions (only if 2+ features need it)
└── [component name + justification]
```

### Decomposition rules
1. **One notifier per screen** — never share a notifier between two screens
2. **One use case per action** — `GetUserProfile` and `UpdateUserProfile` are separate classes
3. **One repository interface per domain** — `UserRepository`, `PostRepository`, `SearchRepository`
4. **Extract to `core/` only when used by 2+ features** — never preemptively
5. **Entities never import models** — conversion happens in repository impl only
6. **Max screen depth: 3 levels** — if deeper, flag for redesign

---

## Step 3: Material 3 UI Patterns

This app uses Material 3. Follow these patterns exactly.

### App shell — bottom navigation
```dart
// Driven by go_router StatefulShellRoute — see flutter-context
// Tab order for this app: Feed | Search | Create | Profile
// (adjust per feature being built)

class AppShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const AppShell({required this.shell, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search),
              label: 'Search'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle), label: 'Create'),
          NavigationDestination(icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
```

### Screen scaffold pattern
```dart
class FeatureScreen extends ConsumerWidget {
  const FeatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(featureNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Title'),
        // Material 3: centerTitle defaults to false on Android, true on iOS
      ),
      body: switch (state) {
        AsyncLoading() => const FeatureSkeleton(),
        AsyncError(:final error) => ErrorView(
            message: 'Could not load',
            onRetry: () => ref.invalidate(featureNotifierProvider),
          ),
        AsyncData(:final value) when value.isEmpty => const EmptyFeatureView(),
        AsyncData(:final value) => FeatureContent(items: value),
      },
    );
  }
}
```

**Use Dart 3 pattern matching on AsyncValue** — cleaner than `.when()` for complex states.

### Loading state — always skeleton, never bare spinner
```dart
class FeatureSkeleton extends StatelessWidget {
  const FeatureSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView.separated(
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, __) => ListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            shape: BoxShape.circle,
          ),
        ),
        title: Container(height: 14, width: 120,
            color: colors.surfaceVariant),
        subtitle: Container(height: 12, width: 80,
            color: colors.surfaceVariant),
      ),
    );
  }
}
```

### Empty state — always branded, never just "No data"
```dart
class EmptyFeatureView extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyFeatureView({
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colors.outline),
            const SizedBox(height: 16),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: text.bodyMedium?.copyWith(color: colors.outline),
                textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
```

---

## Step 4: Seed Feature Patterns

### User Profile

```
Screens:
  ProfileScreen(userId)       — public profile view
  EditProfileScreen           — self-edit (own profile only)

Notifiers:
  ProfileNotifier(userId)     — user data + follow state
  ProfilePostsNotifier        — paginated posts grid (lazy, separate)

Use cases:
  GetUserProfile(userId)
  FollowUser(userId)
  UnfollowUser(userId)
  UpdateUserProfile(params)

Routes:
  /profile              → own profile (tab root)
  /user/:userId         → other user's profile (push)
  /profile/edit         → edit screen (push from own profile)
```

Profile header layout:
```dart
// Always: avatar + stats row + bio + action button
Column(children: [
  CircleAvatar(radius: 40, backgroundImage: ...),
  const SizedBox(height: 12),
  _StatsRow(posts: n, followers: n, following: n),
  const SizedBox(height: 8),
  Text(user.bio),
  const SizedBox(height: 12),
  _ProfileActionButton(user: user),  // "Follow" or "Edit Profile"
])
```

---

### Post Creation

```
Screens:
  CreatePostScreen            — full-screen modal (outside shell)

Notifiers:
  CreatePostNotifier          — form state + submission

Use cases:
  CreatePost(content, mediaFiles)

Routes:
  /create                     — fullscreenDialog: true in go_router
```

Multi-step creation flow (if media involved):
1. Compose screen → text input + media picker
2. Preview/edit screen → crop, caption, visibility
3. Share → submit + optimistic insert into feed

Form state pattern:
```dart
@freezed
class CreatePostState with _$CreatePostState {
  const factory CreatePostState({
    @Default('') String content,
    @Default([]) List<XFile> mediaFiles,
    @Default(ContentVisibility.public) ContentVisibility visibility,
    @Default(false) bool isSubmitting,
    String? errorMessage,
  }) = _CreatePostState;
}
```

---

### Search / Discover

```
Screens:
  SearchScreen                — search bar + discover content when empty
  SearchResultsScreen         — inline in same screen, not a push

Notifiers:
  SearchNotifier              — debounced query, results, history
  DiscoverNotifier            — trending / suggested content

Use cases:
  SearchUsers(query)
  SearchPosts(query)
  GetDiscoverFeed()
```

Debounced search:
```dart
@riverpod
class SearchNotifier extends _$SearchNotifier {
  Timer? _debounce;

  @override
  AsyncValue<SearchResults> build() => const AsyncData(SearchResults.empty());

  void onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      state = const AsyncData(SearchResults.empty());
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(searchUsersProvider).call(query),
    );
  }
}
```

---

## Step 5: File Generation Order

Always generate in this sequence — each layer depends on the one above:

1. **Domain entities** — pure Dart, no dependencies
2. **Domain repository interface** — abstract class
3. **Domain use cases** — one file per use case
4. **Data models** — freezed + json_serializable
5. **Data sources** — remote (+ local if needed)
6. **Repository implementation** — fulfills domain interface
7. **Core providers** — wire up the dependency chain
8. **Presentation notifiers** — consume use cases
9. **Widgets** — skeleton, empty state, error view, content widgets
10. **Screens** — compose widgets, watch notifiers
11. **Router update** — add new routes to `Routes` + `app_router.dart`
12. **Tests** — notifier unit tests + screen widget tests

### Completeness rule
**Every generated file must be complete and compilable.**
No `// TODO`, no `throw UnimplementedError()` in non-abstract classes,
no empty `build()` methods. If a real implementation isn't ready,
use a `MockDataSource` that returns hardcoded data — never a stub.

---

## Step 6: Scaffold Output Format

After generation, always deliver:

1. **Confirmed decomposition** — the layer tree from Step 2
2. **Complete files** — all Dart files, fully implemented
3. **`pubspec.yaml` additions** — any new approved packages needed
4. **Router diff** — exact lines to add to `routes.dart` and `app_router.dart`
5. **Test checklist** — list of test cases to write (handed to `test-writer` skill)
6. **Out of scope** — explicit list of what was NOT built

---

## What the Architect Must NOT Decide

- Directory structure → locked in `flutter-context`
- Which packages to add without asking → locked in `flutter-context`
- Navigation pattern → go_router + StatefulShellRoute always
- Whether to skip spec validation → never skippable, ever
- Layer boundaries → no Flutter imports in domain, no direct API calls in presentation
- UI widget library → Material 3 always, no third-party component libraries without approval

## What the Architect SHOULD Decide

- Whether a use case is needed or a direct repository call suffices
- Sub-widget extraction (when a widget block warrants its own class)
- Skeleton/shimmer design specifics
- Optimistic update strategy per interaction type
- Cache-first vs network-first per data type
- Whether `LocalDataSource` is needed (offline support) or remote-only suffices

---

## Reference Files

- `references/riverpod-wiring.md` — full provider chain examples for complex features
- `references/material3-components.md` — M3 component usage guide for social patterns
- `templates/feature_scaffold.dart` — complete copy-paste feature template
