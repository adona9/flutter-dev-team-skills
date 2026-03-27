# Riverpod Patterns — Social Features

Extended patterns for common social app scenarios using `flutter_riverpod`.
Complements `flutter-architect/references/riverpod-wiring.md` (provider chain setup);
this file covers the runtime patterns.

---

## Optimistic Updates

The standard pattern for actions like like, follow, bookmark — update state immediately,
revert on failure.

```dart
// In the notifier:
Future<void> toggleLike(String postId) async {
  // 1. Snapshot current state
  final previous = state.requireValue;

  // 2. Optimistic update
  state = AsyncData(previous.map((p) =>
    p.id == postId ? p.copyWith(isLiked: !p.isLiked,
      likeCount: p.isLiked ? p.likeCount - 1 : p.likeCount + 1) : p
  ).toList());

  // 3. Network call
  try {
    await ref.read(postRepositoryProvider).toggleLike(postId);
  } catch (e) {
    // 4. Revert on failure
    state = AsyncData(previous);
    rethrow;
  }
}
```

**Rule**: Every optimistic update must have a revert path. No exceptions.

---

## Pagination (cursor-based)

```dart
// State
@freezed
class FeedState with _$FeedState {
  const factory FeedState({
    required List<Post> posts,
    String? nextCursor,
    required bool hasMore,
    required bool isLoadingMore,
  }) = _FeedState;
}

// Notifier
Future<void> loadMore() async {
  if (!state.hasMore || state.isLoadingMore) return;
  state = state.copyWith(isLoadingMore: true);
  try {
    final result = await _repository.getFeed(cursor: state.nextCursor);
    state = state.copyWith(
      posts: [...state.posts, ...result.items],
      nextCursor: result.nextCursor,
      hasMore: result.hasMore,
      isLoadingMore: false,
    );
  } catch (e) {
    state = state.copyWith(isLoadingMore: false);
    rethrow;
  }
}
```

**Rule**: Always guard `loadMore` with `isLoadingMore` to prevent duplicate calls on
rapid scroll.

---

## Cross-provider Invalidation

When an action in one provider should refresh another:

```dart
// After creating a post, invalidate the feed
Future<void> createPost(PostDraft draft) async {
  await _repository.createPost(draft);
  ref.invalidate(feedNotifierProvider);         // feed refreshes
  ref.invalidate(userPostCountProvider);        // profile stat refreshes
}
```

**Rule**: Prefer `invalidate` over manual state mutation across provider boundaries.
Let each provider own its data.

---

## Real-time Updates (polling)

For features that need periodic refresh without websockets:

```dart
@riverpod
class NotificationNotifier extends _$NotificationNotifier {
  Timer? _timer;

  @override
  Future<List<Notification>> build() async {
    ref.onDispose(() => _timer?.cancel());
    _startPolling();
    return _repository.getNotifications();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidateSelf();
    });
  }
}
```

**Rule**: Always cancel timers in `onDispose`. Forgetting this causes state updates
on disposed providers (runtime errors in debug, silent bugs in release).

---

## Provider Families for Per-item State

```dart
// Profile page for any user ID
@riverpod
Future<UserProfile> userProfile(UserProfileRef ref, String userId) {
  return ref.watch(userRepositoryProvider).getProfile(userId);
}

// Usage in widget:
final profile = ref.watch(userProfileProvider(widget.userId));
```

**Rule**: Use families for any provider that varies by an ID. Don't create separate
providers for "my profile" vs "other user profile" — parameterize one.

---

## Error Handling in `.when()`

Always handle all three states. Never use `.value` directly.

```dart
// Correct
ref.watch(feedProvider).when(
  data: (posts) => PostList(posts: posts),
  loading: () => const FeedSkeleton(),
  error: (e, _) => ErrorCard(onRetry: () => ref.invalidate(feedProvider)),
);

// Also acceptable for nullable async
final count = ref.watch(userPostCountProvider).valueOrNull ?? 0;
```

**Never**:
```dart
final posts = ref.watch(feedProvider).value!; // crashes on loading/error
```
