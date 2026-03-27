# Testing Patterns

Quick-reference templates for the three test types used in this project.
For full mocktail setup see `test-writer/references/mocktail-patterns.md`.
For coverage rules see `test-writer/references/coverage-guide.md`.

---

## Widget Test — 4-state template

Every screen must cover: loading, data, empty, error.

```dart
void main() {
  late MockFeatureNotifier mockNotifier;

  setUp(() => mockNotifier = MockFeatureNotifier());

  Widget buildSubject(FeatureState state) {
    return ProviderScope(
      overrides: [
        featureNotifierProvider.overrideWith(() => mockNotifier),
      ],
      child: const MaterialApp(home: FeatureScreen()),
    );
  }

  testWidgets('shows skeleton while loading', (tester) async {
    when(() => mockNotifier.build()).thenAnswer((_) async {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    });
    await tester.pumpWidget(buildSubject(const AsyncLoading()));
    expect(find.byType(FeatureSkeleton), findsOneWidget);
  });

  testWidgets('shows items when data loads', (tester) async {
    when(() => mockNotifier.build()).thenAnswer((_) async => MockData.items);
    await tester.pumpWidget(buildSubject(AsyncData(MockData.items)));
    await tester.pump();
    expect(find.byType(ItemCard), findsWidgets);
  });

  testWidgets('shows empty state with no items', (tester) async {
    when(() => mockNotifier.build()).thenAnswer((_) async => []);
    await tester.pumpWidget(buildSubject(const AsyncData([])));
    await tester.pump();
    expect(find.text('No items yet'), findsOneWidget);
  });

  testWidgets('shows error card on failure', (tester) async {
    when(() => mockNotifier.build()).thenThrow(Exception('network error'));
    await tester.pumpWidget(buildSubject(AsyncError(Exception(), StackTrace.empty)));
    await tester.pump();
    expect(find.byType(ErrorCard), findsOneWidget);
  });
}
```

---

## Notifier Test — optimistic update with revert

```dart
void main() {
  late ProviderContainer container;
  late MockRepository mockRepo;

  setUp(() {
    mockRepo = MockRepository();
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(mockRepo),
    ]);
    addTearDown(container.dispose);
  });

  test('optimistic like reverts on failure', () async {
    when(() => mockRepo.getItems()).thenAnswer((_) async => MockData.items);
    when(() => mockRepo.toggleLike(any())).thenThrow(Exception('network'));

    await container.read(featureNotifierProvider.future);
    final before = container.read(featureNotifierProvider).value!;

    await expectLater(
      () => container.read(featureNotifierProvider.notifier).toggleLike('id1'),
      throwsException,
    );

    final after = container.read(featureNotifierProvider).value!;
    expect(after, equals(before)); // state reverted
  });
}
```

---

## Integration Test — full user flow

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('user can create and view a post', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Navigate to create screen
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Fill form
    await tester.enterText(find.byType(TextField), 'Test post content');
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    // Verify in feed
    expect(find.text('Test post content'), findsOneWidget);
  });
}
```

**Rule**: Integration tests use real providers but mock network layer at the
repository level — never hit actual API endpoints in tests.
