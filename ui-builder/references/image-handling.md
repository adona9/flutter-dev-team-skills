# Image Handling — Social Media Patterns

Aspect ratios, caching, placeholders, and error states for images in a social app.
All image rendering uses `cached_network_image` — never `Image.network`.

---

## Standard Aspect Ratios

| Content type | Ratio | Notes |
|---|---|---|
| Feed post (portrait) | 4:5 | Instagram-style, clips tall images |
| Feed post (square) | 1:1 | Default fallback |
| Feed post (landscape) | 16:9 | Video thumbnails |
| Stories / reels | 9:16 | Full-bleed vertical |
| Avatar (profile) | 1:1 | Always circular, `BoxFit.cover` |
| Avatar (comment/list) | 1:1 | Circular, smaller size |
| Cover / banner | 3:1 | Profile header |

---

## Avatar Widget

```dart
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.imageUrl,
    this.size = AvatarSize.md,
    this.semanticLabel,
  });

  final String? imageUrl;
  final AvatarSize size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? 'User avatar',
      image: true,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl ?? '',
          width: size.dimension,
          height: size.dimension,
          fit: BoxFit.cover,
          placeholder: (_, __) => _Placeholder(size: size),
          errorWidget: (_, __, ___) => _Placeholder(size: size),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});
  final AvatarSize size;

  @override
  Widget build(BuildContext context) => Container(
    width: size.dimension,
    height: size.dimension,
    color: AppColors.surfaceVariant,
    child: Icon(Icons.person, size: size.dimension * 0.5, color: AppColors.onSurfaceVariant),
  );
}
```

---

## Feed Post Image

```dart
class PostImage extends StatelessWidget {
  const PostImage({super.key, required this.imageUrl, this.aspectRatio = 4 / 5});

  final String imageUrl;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => const _ImageSkeleton(),
        errorWidget: (_, __, ___) => const _ImageError(),
      ),
    );
  }
}

class _ImageSkeleton extends StatelessWidget {
  const _ImageSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surfaceVariant,
    // shimmer can be applied here via shimmer package
  );
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surfaceVariant,
    child: const Center(
      child: Icon(Icons.broken_image_outlined, color: AppColors.onSurfaceVariant),
    ),
  );
}
```

---

## Rules

- **Always** provide `placeholder` and `errorWidget` — no bare `CachedNetworkImage`
- **Always** use `semanticLabel` on images that convey content (not decorative)
- **Never** use `Image.network` — no caching, no placeholder support
- **Clip avatars** with `ClipOval`, not `CircleAvatar` (avoids overflow clipping bugs)
- **Pre-cache** images on list screens: `precacheImage(CachedNetworkImageProvider(url), context)` in `initState` or `didChangeDependencies`
- **Max image width**: request appropriately-sized images from the API; don't serve 2000px images for 400px display slots

---

## Cache Configuration

Set once in `main.dart` or `app.dart`:

```dart
PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100MB
```

For explicit cache clearing (e.g., after user logout):
```dart
PaintingBinding.instance.imageCache.clear();
CachedNetworkImage.evictFromCache(imageUrl);
```
