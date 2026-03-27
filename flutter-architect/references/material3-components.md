# Material 3 Components — Social App Usage Guide

Which M3 component to use for which social pattern.
Never use third-party component libraries without approval.

---

## Navigation

| Pattern | M3 Component |
|---|---|
| Bottom tabs | `NavigationBar` + `NavigationDestination` |
| Top-level screen title | `AppBar` (large variant for feed/profile) |
| Sub-screen title | `AppBar` (standard, with back arrow) |
| Modal sheet | `showModalBottomSheet` with `DraggableScrollableSheet` |
| Full-screen modal | `GoRouter` push with `fullscreenDialog: true` |

---

## Content Display

| Pattern | M3 Component |
|---|---|
| Post card | `Card` with `CardTheme` radius from token |
| User list item | `ListTile` with `CircleAvatar` leading |
| Image grid (profile/search) | `GridView.builder` with `SliverGridDelegateWithFixedCrossAxisCount` |
| Infinite list | `ListView.builder` with `NotificationListener<ScrollEndNotification>` |
| Chip filters (search) | `FilterChip` in `Wrap` |
| Tab sections (profile) | `TabBar` + `TabBarView` inside `NestedScrollView` |

---

## Actions

| Pattern | M3 Component |
|---|---|
| Primary CTA | `FilledButton` |
| Secondary action | `OutlinedButton` |
| Follow / like (toggle) | `FilledButton.tonal` (active) / `OutlinedButton` (inactive) |
| Icon action (like, share) | `IconButton` with `IconButton.filled` variant when active |
| FAB (create post) | `FloatingActionButton` — large variant |
| Destructive confirm | `showDialog` with `AlertDialog` — red TextButton for confirm |
| Report / block sheet | `showModalBottomSheet` with `ListTile` items |

---

## Forms (Post Creation, Edit Profile)

| Element | M3 Component |
|---|---|
| Text input | `TextField` with `OutlineInputBorder` |
| Multi-line content | `TextField(maxLines: null, minLines: 4)` |
| Character count | `TextField(maxLength:, counterText: '')` + manual counter `Text` |
| Image picker trigger | `IconButton` in `TextField` suffix or separate `OutlinedButton` |
| Visibility selector | `SegmentedButton<ContentVisibility>` |
| Submit | `FilledButton` (disabled while submitting, shows `CircularProgressIndicator`) |

---

## Feedback

| Pattern | M3 Component |
|---|---|
| Success toast | `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` |
| Error inline | `Text` in `colorScheme.error` below offending field |
| Error full-screen | Custom `ErrorView` widget (see flutter-context patterns) |
| Loading overlay | `Stack` with `ColoredBox(color: Colors.black26)` + `CircularProgressIndicator.adaptive()` |
| Pull to refresh | `RefreshIndicator` wrapping `CustomScrollView` |

---

## Profile Header Pattern

Use `SliverAppBar` + `NestedScrollView` for collapsing header:

```dart
NestedScrollView(
  headerSliverBuilder: (context, _) => [
    SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: ProfileHeader(user: user),
      ),
    ),
    SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(tabs: [Tab(text: 'Posts'), Tab(text: 'Liked')]),
      ),
    ),
  ],
  body: TabBarView(children: [PostsGrid(), LikedGrid()]),
)
```

---

## Theme Setup

```dart
// app.dart
MaterialApp.router(
  theme: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF[CONFIGURE: brand color hex]),
      brightness: Brightness.light,
    ),
  ),
  darkTheme: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF[CONFIGURE: brand color hex]),
      brightness: Brightness.dark,
    ),
  ),
  themeMode: ThemeMode.system,  // respect system setting
  routerConfig: ref.watch(routerProvider),
)
```

Always use `Theme.of(context).colorScheme` for colors — never hardcode hex in widgets.
Always use `Theme.of(context).textTheme` for typography — never hardcode font sizes.
