// TEMPLATE: Copy entire file, rename all occurrences of:
//   Feature / feature / FEATURE → your feature name (e.g. Profile / profile / PROFILE)
//   FeatureItem / feature_item → your entity name (e.g. UserProfile / user_profile)
//
// Delete this comment block before committing.
// Every section marked [CONFIGURE] needs your attention.
// No TODOs should remain in committed code.

// ═══════════════════════════════════════════════════════════════════════════════
// DOMAIN LAYER — lib/features/feature/domain/
// ═══════════════════════════════════════════════════════════════════════════════

// entities/feature_item.dart
// [CONFIGURE] Add fields matching your domain entity
class FeatureItem {
  final String id;
  // Add fields here

  const FeatureItem({required this.id});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FeatureItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// repositories/feature_repository.dart
abstract class FeatureRepository {
  Future<List<FeatureItem>> getItems();
  // [CONFIGURE] Add methods matching your use cases
}

// usecases/get_feature_items.dart
class GetFeatureItems {
  final FeatureRepository _repository;
  const GetFeatureItems(this._repository);

  Future<List<FeatureItem>> call() => _repository.getItems();
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA LAYER — lib/features/feature/data/
// ═══════════════════════════════════════════════════════════════════════════════

// models/feature_item_model.dart
// [CONFIGURE] Use freezed + json_serializable in real implementation
// Replace this stub with:
//   @freezed class FeatureItemModel with _$FeatureItemModel { ... }
class FeatureItemModel {
  final String id;
  const FeatureItemModel({required this.id});

  factory FeatureItemModel.fromJson(Map<String, dynamic> json) =>
      FeatureItemModel(id: json['id'] as String);

  FeatureItem toEntity() => FeatureItem(id: id);
}

// datasources/feature_remote_data_source.dart
abstract class FeatureRemoteDataSource {
  Future<List<FeatureItemModel>> getItems();
}

class FeatureRemoteDataSourceImpl implements FeatureRemoteDataSource {
  // [CONFIGURE] Inject ApiClient from flutter-context core providers
  // final ApiClient _client;
  // FeatureRemoteDataSourceImpl(this._client);

  @override
  Future<List<FeatureItemModel>> getItems() async {
    // [CONFIGURE] Replace with actual API call:
    // final response = await _client.get('/feature-endpoint');
    // return (response.data as List).map((j) => FeatureItemModel.fromJson(j)).toList();
    return [const FeatureItemModel(id: 'mock-1')];
  }
}

// repositories/feature_repository_impl.dart
class FeatureRepositoryImpl implements FeatureRepository {
  final FeatureRemoteDataSource _remote;
  const FeatureRepositoryImpl(this._remote);

  @override
  Future<List<FeatureItem>> getItems() async {
    final models = await _remote.getItems();
    return models.map((m) => m.toEntity()).toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRESENTATION LAYER — lib/features/feature/presentation/
// ═══════════════════════════════════════════════════════════════════════════════

// providers/feature_providers.dart
// [CONFIGURE] Wire up full provider chain — see riverpod-wiring.md for pattern
//
// @riverpod
// FeatureRemoteDataSource featureRemoteDataSource(FeatureRemoteDataSourceRef ref) =>
//     FeatureRemoteDataSourceImpl(ref.watch(apiClientProvider));
//
// @riverpod
// FeatureRepository featureRepository(FeatureRepositoryRef ref) =>
//     FeatureRepositoryImpl(ref.watch(featureRemoteDataSourceProvider));
//
// @riverpod
// GetFeatureItems getFeatureItems(GetFeatureItemsRef ref) =>
//     GetFeatureItems(ref.watch(featureRepositoryProvider));
//
// @riverpod
// class FeatureNotifier extends _$FeatureNotifier {
//   @override
//   Future<List<FeatureItem>> build() =>
//       ref.watch(getFeatureItemsProvider).call();
//
//   Future<void> refresh() async {
//     state = const AsyncLoading();
//     state = await AsyncValue.guard(
//       () => ref.read(getFeatureItemsProvider).call(),
//     );
//   }
// }

// ─── Screens ─────────────────────────────────────────────────────────────────

// screens/feature_screen.dart
// [CONFIGURE] Replace FeatureNotifier + FeatureItem with your actual types
//
// class FeatureScreen extends ConsumerWidget {
//   const FeatureScreen({super.key});
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final state = ref.watch(featureNotifierProvider);
//     return Scaffold(
//       appBar: AppBar(title: const Text('[CONFIGURE: Screen title]')),
//       body: switch (state) {
//         AsyncLoading() => const FeatureSkeleton(),
//         AsyncError(:final error) => ErrorView(
//             message: 'Could not load',
//             onRetry: () => ref.invalidate(featureNotifierProvider),
//           ),
//         AsyncData(:final value) when value.isEmpty => EmptyFeatureView(
//             title: '[CONFIGURE: empty title]',
//             subtitle: '[CONFIGURE: empty subtitle]',
//           ),
//         AsyncData(:final value) => FeatureList(items: value),
//       },
//     );
//   }
// }

// ─── Widgets ─────────────────────────────────────────────────────────────────

// widgets/feature_skeleton.dart — shimmer loading state
// [CONFIGURE] Match skeleton shape to real content layout

// widgets/feature_card.dart — single item card
// [CONFIGURE] Implement with Material 3 Card widget

// widgets/empty_feature_view.dart — empty state
// [CONFIGURE] Use EmptyFeatureView from flutter-context patterns

// ═══════════════════════════════════════════════════════════════════════════════
// ROUTER — lib/router/
// ═══════════════════════════════════════════════════════════════════════════════

// Add to routes.dart:
// static const feature = '/feature';              // tab root
// static const featureDetail = '/feature/:id';    // detail push

// Add to app_router.dart inside appropriate StatefulShellBranch:
// GoRoute(
//   path: Routes.feature,
//   builder: (_, __) => const FeatureScreen(),
//   routes: [
//     GoRoute(
//       path: ':id',
//       builder: (context, state) => FeatureDetailScreen(
//         id: state.pathParameters['id']!,
//       ),
//     ),
//   ],
// ),
