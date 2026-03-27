# Mocktail Patterns

Setup, matchers, and verify patterns for all test types.

---

## Setup

```yaml
# pubspec.yaml dev_dependencies
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
```

## Creating Mocks

```dart
// Always in test file or test/helpers/mocks.dart
// One mock class per interface — never mock concrete classes

class MockPostRepository extends Mock implements PostRepository {}
class MockGetPostFeed extends Mock implements GetPostFeed {}
class MockPostRemoteDataSource extends Mock implements PostRemoteDataSource {}
```

## Registering Fallback Values

Required for custom types used in `any()` matchers:

```dart
setUpAll(() {
  registerFallbackValue(const CreatePostParams(content: '', mediaFiles: []));
  registerFallbackValue(ContentVisibility.public);
});
```

## Stubbing

```dart
// Return value
when(() => mock.getItems()).thenAnswer((_) async => MockData.posts);

// Throw exception
when(() => mock.getItems()).thenThrow(NetworkException('timeout'));

// Return different values on successive calls
var callCount = 0;
when(() => mock.getItems()).thenAnswer((_) async {
  callCount++;
  return callCount == 1 ? [] : MockData.posts;
});

// Stub with argument matching
when(() => mock.getFeed(cursor: null)).thenAnswer((_) async => page1);
when(() => mock.getFeed(cursor: 'abc')).thenAnswer((_) async => page2);
when(() => mock.getFeed(cursor: any(named: 'cursor')))
    .thenAnswer((_) async => MockData.paginatedPosts);
```

## Verification

```dart
// Called exactly once
verify(() => mock.createPost(any())).called(1);

// Called N times
verify(() => mock.fetchFeed(cursor: null)).called(2);

// Never called
verifyNever(() => mock.deletePost(any()));

// Called with specific args
verify(() => mock.toggleLike('post-123')).called(1);

// Called in order
verifyInOrder([
  () => mock.fetchUser('user-1'),
  () => mock.fetchPosts('user-1'),
]);
```

## Capturing Arguments

```dart
final captured = verify(() => mock.createPost(captureAny())).captured;
final params = captured.first as CreatePostParams;
expect(params.content, equals('Hello world'));
```

## Common Test Patterns

### Test that a method is NOT called
```dart
// Act: do something that should NOT trigger the method
await notifier.loadMore();  // when hasMore is false

// Assert
verifyNever(() => mockUseCase.call(cursor: any(named: 'cursor')));
```

### Test async state transitions
```dart
// Watch state changes over time
final states = <AsyncValue<List<Post>>>[];
container.listen(feedNotifierProvider, (_, next) => states.add(next));

// Trigger
await container.read(feedNotifierProvider.notifier).refresh();

// Verify transition: loading → data
expect(states.first, isA<AsyncLoading>());
expect(states.last, isA<AsyncData>());
```

### Test debounced behavior
```dart
testWidgets('debounces search input', (tester) async {
  // Type rapidly
  await tester.enterText(find.byType(SearchField), 'h');
  await tester.pump(const Duration(milliseconds: 100));
  await tester.enterText(find.byType(SearchField), 'he');
  await tester.pump(const Duration(milliseconds: 100));
  await tester.enterText(find.byType(SearchField), 'hello');

  // Debounce hasn't fired yet
  verifyNever(() => mockSearchUseCase.call(any()));

  // Wait for debounce
  await tester.pump(const Duration(milliseconds: 400));

  // Only called once with final value
  verify(() => mockSearchUseCase.call('hello')).called(1);
});
```
