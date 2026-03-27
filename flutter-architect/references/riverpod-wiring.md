# Riverpod Wiring — Full Provider Chain Examples

Complete, working provider chains for the features in this app.
Use these as the blueprint when wiring up new features.

---

## Full Chain: User Profile

```dart
// core/providers/core_providers.dart
@riverpod
ApiClient apiClient(ApiClientRef ref) => ApiClient();

// features/profile/presentation/providers/profile_providers.dart

@riverpod
UserRemoteDataSource userRemoteDataSource(UserRemoteDataSourceRef ref) =>
    UserRemoteDataSourceImpl(ref.watch(apiClientProvider));

@riverpod
UserRepository userRepository(UserRepositoryRef ref) =>
    UserRepositoryImpl(ref.watch(userRemoteDataSourceProvider));

@riverpod
GetUserProfile getUserProfile(GetUserProfileRef ref) =>
    GetUserProfile(ref.watch(userRepositoryProvider));

@riverpod
FollowUser followUser(FollowUserRef ref) =>
    FollowUser(ref.watch(userRepositoryProvider));

// Family notifier — keyed by userId
@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  @override
  Future<UserProfile> build(String userId) =>
      ref.watch(getUserProfileProvider).call(userId);

  Future<void> toggleFollow() async {
    final profile = state.valueOrNull;
    if (profile == null) return;

    // Optimistic update
    state = AsyncData(profile.copyWith(
      isFollowing: !profile.isFollowing,
      followerCount: profile.isFollowing
          ? profile.followerCount - 1
          : profile.followerCount + 1,
    ));

    try {
      await ref.read(followUserProvider).call(profile.id);
    } catch (_) {
      // Revert
      state = AsyncData(profile);
    }
  }
}
```

---

## Full Chain: Search with Debounce

```dart
// features/search/presentation/providers/search_providers.dart

@riverpod
SearchRepository searchRepository(SearchRepositoryRef ref) =>
    SearchRepositoryImpl(ref.watch(userRemoteDataSourceProvider));

@riverpod
SearchUsers searchUsers(SearchUsersRef ref) =>
    SearchUsers(ref.watch(searchRepositoryProvider));

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
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(searchUsersProvider).call(query),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
```

---

## Full Chain: Post Creation with Form State

```dart
// features/create_post/presentation/providers/create_post_providers.dart

@riverpod
PostRepository postRepository(PostRepositoryRef ref) =>
    PostRepositoryImpl(ref.watch(postRemoteDataSourceProvider));

@riverpod
CreatePost createPost(CreatePostRef ref) =>
    CreatePost(ref.watch(postRepositoryProvider));

@riverpod
class CreatePostNotifier extends _$CreatePostNotifier {
  @override
  CreatePostState build() => const CreatePostState();

  void updateContent(String content) =>
      state = state.copyWith(content: content);

  void addMedia(XFile file) =>
      state = state.copyWith(mediaFiles: [...state.mediaFiles, file]);

  void removeMedia(XFile file) =>
      state = state.copyWith(
        mediaFiles: state.mediaFiles.where((f) => f.path != file.path).toList(),
      );

  void setVisibility(ContentVisibility v) =>
      state = state.copyWith(visibility: v);

  Future<bool> submit() async {
    if (state.content.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Post cannot be empty');
      return false;
    }
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await ref.read(createPostProvider).call(
        content: state.content,
        mediaFiles: state.mediaFiles,
        visibility: state.visibility,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to post. Try again.',
      );
      return false;
    }
  }
}
```

Usage in screen:
```dart
ElevatedButton(
  onPressed: state.isSubmitting ? null : () async {
    final success = await ref.read(createPostNotifierProvider.notifier).submit();
    if (success && context.mounted) context.pop();
  },
  child: state.isSubmitting
      ? const SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2))
      : const Text('Post'),
),
```

---

## Sharing State Across Features (invalidation pattern)

When post is created successfully, invalidate the feed so it refreshes:

```dart
// In CreatePostNotifier.submit(), after success:
ref.invalidate(feedNotifierProvider);
```

When user follows someone, invalidate their profile to reflect new count:
```dart
// In FollowNotifier, after success:
ref.invalidate(profileNotifierProvider(userId));
```

**Rule**: Use `ref.invalidate()` for cross-feature updates.
Never pass notifiers between features directly.
