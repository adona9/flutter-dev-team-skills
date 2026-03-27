---
name: ui-builder
description: >
  Use this skill when building any UI component, widget, screen layout, design
  token, or visual element in Flutter. Triggers on: "build a widget", "create a
  component", "design the layout", "make a button", "style this", "add an input",
  "create a form", "image widget", "avatar", "card", "action button", "like button",
  "follow button", "share button", "text field", "design system", "color tokens",
  "typography", "spacing", or any request to produce visual Flutter code. Also
  trigger when flutter-architect produces a component list and hands off to UI
  implementation. ALWAYS load flutter-context first.
---

# UI Builder

Produces complete, production-quality Flutter widgets and design system tokens.
Dark-first. Content-first. Minimal chrome. Material 3 foundation.

**Depends on**: `flutter-context` — inherits layer rules, approved packages,
directory structure.

---

## Design System: Tokens

All visual decisions flow from these tokens. Never hardcode colors, sizes,
or typography in widgets — always reference tokens.

### Color System

```dart
// lib/design_system/tokens/colors.dart
//
// Philosophy: near-black backgrounds, near-white text, zinc neutrals,
// one functional accent (white). Content IS the color — UI chrome stays
// out of the way.

abstract class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────────────────
  // Layered dark surfaces — each step slightly lighter
  static const background     = Color(0xFF0A0A0A);  // true canvas
  static const surface        = Color(0xFF141414);  // cards, sheets
  static const surfaceVariant = Color(0xFF1F1F1F);  // input fields, chips
  static const surfaceHigh    = Color(0xFF2A2A2A);  // hover, pressed states

  // ── Content ──────────────────────────────────────────────────────────────
  static const onBackground   = Color(0xFFF5F5F5);  // primary text
  static const onSurface      = Color(0xFFE8E8E8);  // body text on cards
  static const onSurfaceMuted = Color(0xFF9E9E9E);  // secondary text, timestamps
  static const onSurfaceFaint = Color(0xFF616161);  // placeholders, disabled

  // ── Accent (functional only — not decorative) ────────────────────────────
  static const accent         = Color(0xFFFFFFFF);  // primary actions, links
  static const accentMuted    = Color(0xFFE0E0E0);  // secondary actions

  // ── Feedback ─────────────────────────────────────────────────────────────
  static const error          = Color(0xFFCF6679);  // errors (M3 dark error)
  static const errorContainer = Color(0xFF8C1D18);  // error backgrounds
  static const success        = Color(0xFF4CAF50);  // confirmations
  static const like           = Color(0xFFE57373);  // liked state (soft red)

  // ── Borders & Dividers ───────────────────────────────────────────────────
  static const outline        = Color(0xFF2C2C2C);  // card borders
  static const divider        = Color(0xFF1C1C1C);  // list dividers

  // ── Media overlays ───────────────────────────────────────────────────────
  static const scrim          = Color(0xCC000000);  // 80% black over images
  static const scrimLight     = Color(0x66000000);  // 40% black for gradients
}
```

### Typography System

```dart
// lib/design_system/tokens/typography.dart
//
// Scale: compact for dense social content. Inter or system font.
// Weights do the heavy lifting — not size variation.

abstract class AppTypography {
  static const _fontFamily = 'Inter';  // add to pubspec + assets, or use null for system

  static TextTheme get textTheme => const TextTheme(
    // Display — hero moments only (profile name on own profile, etc.)
    displaySmall:   TextStyle(fontFamily: _fontFamily, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),

    // Headlines — screen titles, section headers
    headlineMedium: TextStyle(fontFamily: _fontFamily, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
    headlineSmall:  TextStyle(fontFamily: _fontFamily, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),

    // Titles — card titles, username (prominent)
    titleLarge:     TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
    titleMedium:    TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600),
    titleSmall:     TextStyle(fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w500),

    // Body — post content, bio, descriptions
    bodyLarge:      TextStyle(fontFamily: _fontFamily, fontSize: 15, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium:     TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
    bodySmall:      TextStyle(fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w400, height: 1.4),

    // Labels — timestamps, counts, chips, captions
    labelLarge:     TextStyle(fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w500),
    labelMedium:    TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall:     TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 0.3),
  );
}
```

### Spacing System

```dart
// lib/design_system/tokens/spacing.dart
//
// 4pt base grid. All spacing is a multiple of 4.

abstract class AppSpacing {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 12.0;
  static const lg  = 16.0;
  static const xl  = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  // Content-specific
  static const screenPadding   = lg;    // horizontal padding on screens
  static const cardPadding      = lg;    // internal card padding
  static const sectionGap       = xxl;   // between content sections
  static const listItemGap      = sm;    // between list items
  static const avatarTextGap    = sm;    // avatar → username
  static const iconTextGap      = xs;    // icon → label in action buttons
}
```

### Border Radius System

```dart
// lib/design_system/tokens/radius.dart
abstract class AppRadius {
  static const xs  = BorderRadius.all(Radius.circular(4));
  static const sm  = BorderRadius.all(Radius.circular(8));
  static const md  = BorderRadius.all(Radius.circular(12));
  static const lg  = BorderRadius.all(Radius.circular(16));
  static const xl  = BorderRadius.all(Radius.circular(24));
  static const full = BorderRadius.all(Radius.circular(999)); // pills, avatars
}
```

---

## Component Library

### 1. App Theme

```dart
// lib/app.dart — ThemeData configuration
ThemeData _buildTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme(
    brightness: Brightness.dark,
    primary:          AppColors.accent,
    onPrimary:        AppColors.background,
    secondary:        AppColors.accentMuted,
    onSecondary:      AppColors.background,
    surface:          AppColors.surface,
    onSurface:        AppColors.onSurface,
    background:       AppColors.background,
    onBackground:     AppColors.onBackground,
    error:            AppColors.error,
    onError:          AppColors.onBackground,
    outline:          AppColors.outline,
    surfaceVariant:   AppColors.surfaceVariant,
    onSurfaceVariant: AppColors.onSurfaceMuted,
  ),
  textTheme: AppTypography.textTheme,
  scaffoldBackgroundColor: AppColors.background,
  appBarTheme: AppBarTheme(
    backgroundColor:  AppColors.background,
    foregroundColor:  AppColors.onBackground,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: AppTypography.textTheme.titleLarge?.copyWith(
      color: AppColors.onBackground,
    ),
  ),
  cardTheme: CardTheme(
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.md,
      side: BorderSide(color: AppColors.outline),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.divider,
    space: 1,
    thickness: 1,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceVariant,
    border: OutlineInputBorder(
      borderRadius: AppRadius.sm,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.sm,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.sm,
      borderSide: const BorderSide(color: AppColors.accent, width: 1),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppRadius.sm,
      borderSide: const BorderSide(color: AppColors.error, width: 1),
    ),
    hintStyle: AppTypography.textTheme.bodyMedium?.copyWith(
      color: AppColors.onSurfaceFaint,
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    indicatorColor: AppColors.surfaceHigh,
    iconTheme: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return const IconThemeData(color: AppColors.onBackground, size: 24);
      }
      return const IconThemeData(color: AppColors.onSurfaceMuted, size: 24);
    }),
    labelTextStyle: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return AppTypography.textTheme.labelSmall?.copyWith(
          color: AppColors.onBackground,
        );
      }
      return AppTypography.textTheme.labelSmall?.copyWith(
        color: AppColors.onSurfaceMuted,
      );
    }),
  ),
);
```

---

### 2. Avatar Widget

```dart
// lib/design_system/components/app_avatar.dart

enum AvatarSize { xs, sm, md, lg, xl }

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackInitial;  // shown when no image
  final AvatarSize size;
  final VoidCallback? onTap;

  const AppAvatar({
    required this.fallbackInitial,
    this.imageUrl,
    this.size = AvatarSize.md,
    this.onTap,
    super.key,
  });

  double get _diameter => switch (size) {
    AvatarSize.xs => 24,
    AvatarSize.sm => 32,
    AvatarSize.md => 40,
    AvatarSize.lg => 56,
    AvatarSize.xl => 80,
  };

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: _diameter,
      height: _diameter,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceVariant,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => const ColoredBox(color: AppColors.surfaceVariant),
              errorWidget: (_, __, ___) => _Fallback(initial: fallbackInitial, diameter: _diameter),
            )
          : _Fallback(initial: fallbackInitial, diameter: _diameter),
    );

    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}

class _Fallback extends StatelessWidget {
  final String initial;
  final double diameter;
  const _Fallback({required this.initial, required this.diameter});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      initial.isNotEmpty ? initial[0].toUpperCase() : '?',
      style: TextStyle(
        color: AppColors.onSurfaceMuted,
        fontSize: diameter * 0.38,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
```

---

### 3. Action Buttons (Like, Follow, Share)

```dart
// lib/design_system/components/action_buttons.dart

// ── Like Button ──────────────────────────────────────────────────────────────
class LikeButton extends StatelessWidget {
  final bool isLiked;
  final int count;
  final VoidCallback onTap;

  const LikeButton({
    required this.isLiked,
    required this.count,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(isLiked),
                size: 22,
                color: isLiked ? AppColors.like : AppColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              _formatCount(count),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isLiked ? AppColors.like : AppColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ── Follow Button ─────────────────────────────────────────────────────────────
class FollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onTap;
  final bool compact;  // true = icon only, false = full label

  const FollowButton({
    required this.isFollowing,
    required this.onTap,
    this.compact = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (isFollowing) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          side: const BorderSide(color: AppColors.outline),
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs)
              : const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(compact ? 'Following' : 'Following',
            style: Theme.of(context).textTheme.labelLarge),
      );
    }

    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.background,
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs)
            : const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text('Follow', style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppColors.background,
        fontWeight: FontWeight.w600,
      )),
    );
  }
}

// ── Share Button ──────────────────────────────────────────────────────────────
class ShareButton extends StatelessWidget {
  final VoidCallback onTap;

  const ShareButton({required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: Icon(Icons.ios_share_outlined, size: 22, color: AppColors.onSurfaceMuted),
      ),
    );
  }
}
```

---

### 4. Input Fields + Forms

```dart
// lib/design_system/components/app_text_field.dart

class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final Widget? prefix;
  final Widget? suffix;
  final void Function(String)? onChanged;
  final bool autofocus;

  const AppTextField({
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.autofocus = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.onSurfaceMuted,
            )),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          autofocus: autofocus,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.onBackground,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefix,
            suffixIcon: suffix,
            counterText: maxLength != null ? null : '',
          ),
        ),
      ],
    );
  }
}

// ── Post content input (multi-line, auto-expand) ──────────────────────────────
class PostContentField extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onChanged;
  static const _maxChars = 500;

  const PostContentField({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        final remaining = _maxChars - value.text.length;
        final isNearLimit = remaining < 50;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppTextField(
              controller: controller,
              hint: "What's happening?",
              maxLines: null,
              maxLength: _maxChars,
              onChanged: onChanged,
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$remaining',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isNearLimit ? AppColors.error : AppColors.onSurfaceFaint,
              ),
            ),
          ],
        );
      },
    );
  }
}
```

---

### 5. Network Image with Dark Overlay

```dart
// lib/design_system/components/app_network_image.dart

class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? overlay;  // optional gradient/text overlay

  const AppNetworkImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.overlay,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: AppColors.surfaceVariant,
      ),
      errorWidget: (_, __, ___) => Container(
        width: width,
        height: height,
        color: AppColors.surfaceVariant,
        child: const Icon(Icons.broken_image_outlined,
            color: AppColors.onSurfaceFaint),
      ),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    if (overlay == null) return image;

    return Stack(
      children: [
        image,
        Positioned.fill(child: overlay!),
      ],
    );
  }
}

// ── Gradient overlay for image + text (e.g. post cards with caption) ──────────
class ImageGradientOverlay extends StatelessWidget {
  final Widget child;  // content shown above gradient

  const ImageGradientOverlay({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, AppColors.scrim],
          stops: [0.4, 1.0],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}
```

---

## Widget Generation Rules

**Always follow these when building any new component:**

1. **Token-only** — never hardcode `Color(0xFF...)`, font sizes, or padding values in widgets. Always `AppColors.*`, `AppSpacing.*`, `AppTypography.*`
2. **Dark-first** — design for dark theme, verify light theme works but don't optimise for it
3. **Content-first** — UI chrome (borders, backgrounds, icons) uses muted colors. User content (text, images) gets full contrast
4. **No third-party UI packages** — use M3 + custom components from this library only
5. **Const constructors** — every widget that can be `const`, is `const`
6. **Semantic sizing** — use `AvatarSize.md` not `40.0`; use `AppSpacing.lg` not `16.0`
7. **Hit targets** — all tappable elements minimum 44×44 logical pixels (iOS HIG)
8. **Accessible** — every image has `semanticLabel`; every icon button has `tooltip`

---

## Reference Files

- `references/dark-theme-guide.md` — dark UI pitfalls, elevation, surface layering
- `references/image-handling.md` — aspect ratios, caching, placeholders for social media
- `templates/component.dart.template` — blank component starting point
