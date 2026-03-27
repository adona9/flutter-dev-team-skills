# Social App Patterns — Flutter + Riverpod

Common patterns for consumer/social features. Use as starting points.

---

## Pagination (Cursor-based)

```dart
// Domain entity
class PaginatedResult<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  const PaginatedResult({required this.items, this.nextCursor, required this.hasMore});
}

// Notifier with load-more
@riverpod
class FeedNotifier extends _$FeedNotifier {
  String? _cursor;
  bool _hasMore = true;

  @override
  Future<List<Post>> build() async {
    _cursor = null;
    _hasMore = true;
    final result = await ref.watch(getPostFeedProvider).call(cursor: null);
    _cursor = result.nextCursor;
    _hasMore = result.hasMore;
    return result.items;
  }

  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading) return;
    final current = state.valueOrNull ?? [];
    final result = await ref.read(getPostFeedProvider).call(cursor: _cursor);
    _cursor = result.nextCursor;
    _hasMore = result.hasMore;
    state = AsyncData([...current, ...result.items]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    ref.invalidateSelf();
    await future;
  }
}
```

Trigger `loadMore()` in widget:
```dart
NotificationListener<ScrollEndNotification>(
  onNotification: (notification) {
    if (notification.metrics.extentAfter < 200) {
      ref.read(feedNotifierProvider.notifier).loadMore();
    }
    return false;
  },
  child: ListView.builder(...),
)
```

---

## Optimistic Updates (Like / Follow)

```dart
Future<void> toggleLike(String postId) async {
  // Read current state
  final posts = state.valueOrNull ?? [];
  final index = posts.indexWhere((p) => p.id == postId);
  if (index == -1) return;

  final post = posts[index];
  final optimistic = post.copyWith(
    isLiked: !post.isLiked,
    likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1,
  );

  // Apply optimistic update immediately
  final updated = [...posts];
  updated[index] = optimistic;
  state = AsyncData(updated);

  // Attempt server call
  try {
    await ref.read(postRepositoryProvider).toggleLike(postId);
  } catch (_) {
    // Revert on failure
    updated[index] = post;
    state = AsyncData([...updated]);
  }
}
```

---

## Pull to Refresh

```dart
RefreshIndicator(
  onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
  child: feedList,
)
```

---

## Error + Retry Pattern

```dart
// Reusable error widget
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorView({required this.message, required this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

// Usage in screen
error: (err, _) => ErrorView(
  message: 'Could not load feed',
  onRetry: () => ref.invalidate(feedNotifierProvider),
),
```

---

## Content Visibility

```dart
enum ContentVisibility { public, followers, private }

// Never make visibility decisions in the app —
// server returns only what the user is allowed to see.
// Model it for display/creation purposes only.
```

---

## Report Sheet

```dart
void _showReportSheet(BuildContext context, Post post) {
  showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text("It's spam"),
            onTap: () {
              Navigator.pop(context);
              ref.read(postActionsProvider).report(post.id, reason: 'spam');
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Inappropriate content'),
            onTap: () {
              Navigator.pop(context);
              ref.read(postActionsProvider).report(post.id, reason: 'inappropriate');
            },
          ),
        ],
      ),
    ),
  );
}
```
