---
name: test-writer
description: >
  Use this skill when writing, generating, or fixing any tests in Flutter.
  Triggers on: "write tests", "add tests", "test this", "write a unit test",
  "widget test", "integration test", "test the notifier", "test the repository",
  "test the screen", "test this use case", "coverage", "failing test", "fix test",
  or whenever flutter-architect hands off a test checklist. Also trigger when
  the user asks "is this tested?" or "what tests do I need?". ALWAYS load
  flutter-context first. Produces complete, runnable test files — never stubs.
---

# Test Writer

Generates complete, strict, runnable Flutter tests.
Three types: unit (notifiers, use cases, repositories), widget (screens,
components), and integration (full user flows). All must be fully implemented —
no `// TODO` in test files, ever.

**Depends on**: `flutter-context` — inherits project structure, Riverpod patterns,
directory layout.

**Coverage enforcement**: 80% line coverage minimum. Build fails below this.

---

## Coverage Gate

Run before every PR merge and every iOS build:

```bash
bash scripts/check_coverage.sh
```

Threshold: **80% line coverage**. Configurable in `scripts/check_coverage.sh`.
The build pipeline in `flutter-context/scripts/build_ios.sh` calls this
automatically before building — fix coverage before the build runs.

---

## Test Directory Layout

```
test/
├── unit/
│   ├── features/
│   │   └── feature_name/
│   │       ├── notifiers/
│   │       │   └── feature_notifier_test.dart
│   │       ├── usecases/
│   │       │   └── get_feature_items_test.dart
│   │       └── repositories/
│   │           └── feature_repository_test.dart
│   └── core/
│       └── utils/
├── widget/
│   └── features/
│       └── feature_name/
│           ├── feature_screen_test.dart
│           └── components/
│               └── feature_card_test.dart
└── integration/
    └── flows/
        └── feature_flow_test.dart
```

---

## Type 1: Unit Tests

### Notifier tests — always test all state transitions

```dart
// test/unit/features/feed/notifiers/feed_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mock dependencies
class MockGetPostFeed extends Mock implements GetPostFeed {}

void main() {
  late MockGetPostFeed mockGetPostFeed;
  late ProviderContainer container;

  setUp(() {
    mockGetPostFeed = MockGetPostFeed();
    container = ProviderContainer(
      overrides: [
        // Override the use case provider with mock
        getPostFeedProvider.overrideWithValue(mockGetPostFeed),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('FeedNotifier', () {
    test('initial state is AsyncLoading', () {
      // Arrange: mock returns valid data eventually
      when(() => mockGetPostFeed.call(cursor: any(named: 'cursor')))
          .thenAnswer((_) async => PaginatedResult(
                items: MockData.posts,
                nextCursor: null,
                hasMore: false,
              ));

      // Act
      final notifier = container.read(feedNotifierProvider);

      // Assert: starts loading
      expect(notifier, isA<AsyncLoading>());
    });

    test('loads posts successfully', () async {
      // Arrange
      final posts = MockData.posts;
      when(() => mockGetPostFeed.call(cursor: any(named: 'cursor')))
          .thenAnswer((_) async => PaginatedResult(
                items: posts,
                nextCursor: null,
                hasMore: false,
              ));

      // Act
      await container.read(feedNotifierProvider.future);

      // Assert
      final state = container.read(feedNotifierProvider);
      expect(state, isA<AsyncData<List<Post>>>());
      expect(state.value, equals(posts));
    });

    test('transitions to error state on failure', () async {
      // Arrange
      when(() => mockGetPostFeed.call(cursor: any(named: 'cursor')))
          .thenThrow(Exception('Network error'));

      // Act
      await container.read(feedNotifierProvider.future).catchError((_) => <Post>[]);

      // Assert
      final state = container.read(feedNotifierProvider);
      expect(state, isA<AsyncError>());
    });

    test('loadMore appends to existing posts', () async {
      // Arrange: first call returns page 1 with cursor
      final page1 = MockData.posts.take(3).toList();
      final page2 = MockData.posts.skip(3).toList();

      when(() => mockGetPostFeed.call(cursor: null))
          .thenAnswer((_) async => PaginatedResult(
                items: page1,
                nextCursor: 'cursor-abc',
                hasMore: true,
              ));
      when(() => mockGetPostFeed.call(cursor: 'cursor-abc'))
          .thenAnswer((_) async => PaginatedResult(
                items: page2,
                nextCursor: null,
                hasMore: false,
              ));

      // Act: initial load
      await container.read(feedNotifierProvider.future);
      // Act: load more
      await container.read(feedNotifierProvider.notifier).loadMore();

      // Assert: combined
      final state = container.read(feedNotifierProvider);
      expect(state.value?.length, equals(page1.length + page2.length));
    });

    test('optimistic like toggles isLiked and count', () async {
      // Arrange
      final posts = MockData.posts;
      when(() => mockGetPostFeed.call(cursor: any(named: 'cursor')))
          .thenAnswer((_) async => PaginatedResult(items: posts, nextCursor: null, hasMore: false));

      await container.read(feedNotifierProvider.future);
      final originalPost = container.read(feedNotifierProvider).value!.first;

      // Act: toggle like
      await container.read(feedNotifierProvider.notifier).toggleLike(originalPost.id);

      // Assert: optimistic update applied
      final updated = container.read(feedNotifierProvider).value!.first;
      expect(updated.isLiked, equals(!originalPost.isLiked));
      expect(updated.likeCount,
          equals(originalPost.isLiked ? originalPost.likeCount - 1 : originalPost.likeCount + 1));
    });

    test('reverts optimistic like on API failure', () async {
      // Arrange
      final posts = MockData.posts;
      when(() => mockGetPostFeed.call(cursor: any(named: 'cursor')))
          .thenAnswer((_) async => PaginatedResult(items: posts, nextCursor: null, hasMore: false));

      await container.read(feedNotifierProvider.future);
      final originalPost = container.read(feedNotifierProvider).value!.first;

      // Simulate API failure for toggle
      // (wire up mock post actions provider similarly)

      // Assert: reverted to original
      final afterRevert = container.read(feedNotifierProvider).value!.first;
      expect(afterRevert.isLiked, equals(originalPost.isLiked));
      expect(afterRevert.likeCount, equals(originalPost.likeCount));
    });
  });
}
```

### Use case tests — test the contract, mock the repository

```dart
// test/unit/features/feed/usecases/get_post_feed_test.dart
void main() {
  late MockPostRepository mockRepository;
  late GetPostFeed useCase;

  setUp(() {
    mockRepository = MockPostRepository();
    useCase = GetPostFeed(mockRepository);
  });

  group('GetPostFeed', () {
    test('returns posts from repository', () async {
      final expected = PaginatedResult(
        items: MockData.posts,
        nextCursor: null,
        hasMore: false,
      );
      when(() => mockRepository.getFeed(cursor: null))
          .thenAnswer((_) async => expected);

      final result = await useCase.call(cursor: null);

      expect(result, equals(expected));
      verify(() => mockRepository.getFeed(cursor: null)).called(1);
    });

    test('passes cursor to repository', () async {
      when(() => mockRepository.getFeed(cursor: 'abc'))
          .thenAnswer((_) async => PaginatedResult(items: [], nextCursor: null, hasMore: false));

      await useCase.call(cursor: 'abc');

      verify(() => mockRepository.getFeed(cursor: 'abc')).called(1);
    });

    test('propagates repository exceptions', () async {
      when(() => mockRepository.getFeed(cursor: any(named: 'cursor')))
          .thenThrow(NetworkException('timeout'));

      expect(() => useCase.call(cursor: null), throwsA(isA<NetworkException>()));
    });
  });
}
```

### Repository tests — mock the data source

```dart
// test/unit/features/feed/repositories/post_repository_test.dart
void main() {
  late MockPostRemoteDataSource mockRemote;
  late PostRepositoryImpl repository;

  setUp(() {
    mockRemote = MockPostRemoteDataSource();
    repository = PostRepositoryImpl(mockRemote);
  });

  group('PostRepositoryImpl', () {
    test('maps models to entities correctly', () async {
      when(() => mockRemote.getFeed(cursor: null))
          .thenAnswer((_) async => MockData.postModels);

      final result = await repository.getFeed(cursor: null);

      expect(result.items, isA<List<Post>>());
      expect(result.items.length, equals(MockData.postModels.length));
      expect(result.items.first.id, equals(MockData.postModels.first.id));
    });

    test('wraps data source exceptions in domain failures', () async {
      when(() => mockRemote.getFeed(cursor: null))
          .thenThrow(const SocketException('no connection'));

      expect(
        () => repository.getFeed(cursor: null),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
```

---

## Type 2: Widget Tests — all 4 states, every screen

### Screen test template — strict 4-state coverage

```dart
// test/widget/features/feed/feed_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Helper: builds screen with Riverpod overrides + dark theme
Widget buildTestApp(List<Override> overrides, Widget screen) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: screen,
    ),
  );
}

void main() {
  group('FeedScreen', () {
    // ── State 1: Loading ────────────────────────────────────────────────────
    testWidgets('shows skeleton while loading', (tester) async {
      await tester.pumpWidget(buildTestApp(
        [
          feedNotifierProvider.overrideWith(() => MockFeedNotifier(
            state: const AsyncLoading(),
          )),
        ],
        const FeedScreen(),
      ));

      // Don't pumpAndSettle — we want to catch the loading state
      await tester.pump();

      expect(find.byType(FeedSkeleton), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);
    });

    // ── State 2: Error ──────────────────────────────────────────────────────
    testWidgets('shows error view with retry button on failure', (tester) async {
      await tester.pumpWidget(buildTestApp(
        [
          feedNotifierProvider.overrideWith(() => MockFeedNotifier(
            state: AsyncError(Exception('Network error'), StackTrace.empty),
          )),
        ],
        const FeedScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(FeedSkeleton), findsNothing);
    });

    // ── State 3: Empty ──────────────────────────────────────────────────────
    testWidgets('shows empty state when no posts', (tester) async {
      await tester.pumpWidget(buildTestApp(
        [
          feedNotifierProvider.overrideWith(() => MockFeedNotifier(
            state: const AsyncData([]),
          )),
        ],
        const FeedScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyFeatureView), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);
    });

    // ── State 4: Data ───────────────────────────────────────────────────────
    testWidgets('shows post list when data loaded', (tester) async {
      final posts = MockData.posts;

      await tester.pumpWidget(buildTestApp(
        [
          feedNotifierProvider.overrideWith(() => MockFeedNotifier(
            state: AsyncData(posts),
          )),
        ],
        const FeedScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PostCard), findsNWidgets(posts.length));
      expect(find.byType(FeedSkeleton), findsNothing);
      expect(find.byType(ErrorView), findsNothing);
    });

    // ── Interactions ────────────────────────────────────────────────────────
    testWidgets('retry button calls refresh', (tester) async {
      final mockNotifier = MockFeedNotifier(
        state: AsyncError(Exception('error'), StackTrace.empty),
      );

      await tester.pumpWidget(buildTestApp(
        [feedNotifierProvider.overrideWith(() => mockNotifier)],
        const FeedScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      verify(() => mockNotifier.refresh()).called(1);
    });

    testWidgets('pull to refresh calls refresh', (tester) async {
      final mockNotifier = MockFeedNotifier(state: AsyncData(MockData.posts));

      await tester.pumpWidget(buildTestApp(
        [feedNotifierProvider.overrideWith(() => mockNotifier)],
        const FeedScreen(),
      ));
      await tester.pumpAndSettle();

      // Simulate pull-to-refresh
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      verify(() => mockNotifier.refresh()).called(1);
    });
  });
}
```

### Component test template

```dart
// test/widget/features/feed/components/post_card_test.dart
void main() {
  group('PostCard', () {
    testWidgets('displays author name and content', (tester) async {
      final post = MockData.posts.first;

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: Scaffold(body: PostCard(post: post)),
      ));

      expect(find.text(post.author.displayName), findsOneWidget);
      expect(find.text(post.content), findsOneWidget);
    });

    testWidgets('like button triggers callback', (tester) async {
      final post = MockData.posts.first;
      var likeTapped = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PostCard(post: post, onLike: () => likeTapped = true),
        ),
      ));

      await tester.tap(find.byType(LikeButton));
      expect(likeTapped, isTrue);
    });

    testWidgets('shows liked state correctly', (tester) async {
      final likedPost = MockData.posts.first.copyWith(isLiked: true);
      final unlikedPost = MockData.posts.first.copyWith(isLiked: false);

      // Liked state
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PostCard(post: likedPost)),
      ));
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      // Unliked state
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PostCard(post: unlikedPost)),
      ));
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });
  });
}
```

---

## Type 3: Integration Tests — full user flows

```dart
// test/integration/flows/create_post_flow_test.dart
//
// Integration tests use real Riverpod but with mocked data sources.
// They test complete user flows across multiple screens.

void main() {
  group('Create Post Flow', () {
    testWidgets('user can write and submit a post', (tester) async {
      final mockPostDataSource = MockPostRemoteDataSource();
      when(() => mockPostDataSource.createPost(any()))
          .thenAnswer((_) async => MockData.postModels.first);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          postRemoteDataSourceProvider.overrideWithValue(mockPostDataSource),
        ],
        child: const MaterialApp(home: AppShell()),
      ));
      await tester.pumpAndSettle();

      // Navigate to create tab
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      // Type content
      await tester.enterText(find.byType(PostContentField), 'Hello world!');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      // Verify: returned to feed, post API called
      verify(() => mockPostDataSource.createPost(any())).called(1);
      expect(find.byType(FeedScreen), findsOneWidget);
    });

    testWidgets('shows error if post submission fails', (tester) async {
      final mockPostDataSource = MockPostRemoteDataSource();
      when(() => mockPostDataSource.createPost(any()))
          .thenThrow(Exception('Server error'));

      await tester.pumpWidget(ProviderScope(
        overrides: [
          postRemoteDataSourceProvider.overrideWithValue(mockPostDataSource),
        ],
        child: const MaterialApp(home: CreatePostScreen()),
      ));

      await tester.enterText(find.byType(PostContentField), 'Hello!');
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to post. Try again.'), findsOneWidget);
      expect(find.byType(CreatePostScreen), findsOneWidget); // stayed on screen
    });
  });
}
```

---

## Mock Data — centralised

```dart
// test/helpers/mock_data.dart
//
// Single source of mock objects for all tests.
// Never duplicate mock data across test files.

abstract class MockData {
  static final users = [
    User(
      id: 'user-1',
      username: 'alice',
      displayName: 'Alice Chen',
      avatarURL: null,
      followerCount: 1200,
      followingCount: 340,
      isFollowing: false,
    ),
    User(
      id: 'user-2',
      username: 'bob',
      displayName: 'Bob Kim',
      avatarURL: null,
      followerCount: 890,
      followingCount: 120,
      isFollowing: true,
    ),
  ];

  static final posts = [
    Post(
      id: 'post-1',
      author: users.first,
      content: 'First post content for testing',
      mediaURLs: [],
      likeCount: 42,
      commentCount: 7,
      isLiked: false,
      createdAt: DateTime(2024, 1, 15, 10, 30),
    ),
    Post(
      id: 'post-2',
      author: users.last,
      content: 'Second post with image',
      mediaURLs: [Uri.parse('https://example.com/image.jpg')],
      likeCount: 128,
      commentCount: 23,
      isLiked: true,
      createdAt: DateTime(2024, 1, 15, 9, 0),
    ),
  ];

  // Models (data layer) — used in repository tests
  static final postModels = posts
      .map((p) => PostModel(
            id: p.id,
            authorId: p.author.id,
            content: p.content,
            // ... map all fields
          ))
      .toList();
}
```

---

## Mock Notifiers — reusable across widget tests

```dart
// test/helpers/mock_notifiers.dart

class MockFeedNotifier extends FeedNotifier {
  final AsyncValue<List<Post>> _initialState;
  MockFeedNotifier({required AsyncValue<List<Post>> state})
      : _initialState = state;

  @override
  Future<List<Post>> build() async {
    state = _initialState;
    return _initialState.value ?? [];
  }

  @override
  Future<void> refresh() async {}  // no-op by default, verify with mocktail

  @override
  Future<void> loadMore() async {}
}
```

---

## What the Test Writer Should NOT Decide

1. **Coverage threshold** — locked at 80%. Never lower it for convenience
2. **Which states to test** — all 4 (loading, error, empty, data) for every screen, always
3. **Mock data location** — always `test/helpers/mock_data.dart`, never inline
4. **Test file location** — mirrors `lib/` structure under `test/`
5. **Whether to skip a test type** — all three types (unit, widget, integration) are required

## What the Test Writer SHOULD Decide

- Test case naming (should be descriptive sentences, not `test1`, `test2`)
- Which interactions to test beyond the mandatory 4 states
- Whether a component needs its own test file or can be covered by screen test
- Complexity of integration test flows (1-screen vs multi-screen)
- Which edge cases are worth an explicit test vs covered implicitly

---

## Reference Files

- `references/mocktail-patterns.md` — mocktail setup, common matchers, verify patterns
- `references/coverage-guide.md` — what counts toward coverage, exclusions, CI setup
- `templates/notifier_test.dart.template` — blank notifier test
- `templates/screen_test.dart.template` — blank screen test with all 4 states
