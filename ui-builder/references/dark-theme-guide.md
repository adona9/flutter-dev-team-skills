# Dark Theme Guide

Pitfalls, patterns, and rules for dark-first Flutter UI.

---

## Surface Layering (elevation without light)

Material 3 uses tonal elevation — surfaces get lighter as they go higher.
In dark mode, we control this manually with our surface token stack:

```
background     #0A0A0A  ← base canvas (deepest)
surface        #141414  ← cards, sheets, nav bar
surfaceVariant #1F1F1F  ← inputs, chips, pressed states
surfaceHigh    #2A2A2A  ← tooltips, menus, highest layer
```

**Rule**: Each layer should be visually distinct but not jarring.
The difference between adjacent layers is ~8–10% brightness, not 50%.

Never use `elevation` with `surfaceTintColor` in dark mode — disable it:
```dart
surfaceTintColor: Colors.transparent,  // always
elevation: 0,                          // use surface layering instead
```

---

## Text Contrast Hierarchy

Use these consistently — never full white for everything:

```
onBackground  #F5F5F5  ← headlines, primary content, names
onSurface     #E8E8E8  ← body text inside cards
onSurfaceMuted #9E9E9E ← secondary info (timestamps, counts, labels)
onSurfaceFaint #616161 ← placeholders, hints, disabled text
```

**Why not pure white (#FFFFFF)?**
Pure white on near-black creates extreme contrast that causes eye strain
over long use sessions — exactly what a social app wants to avoid.
#F5F5F5 is indistinguishable in casual use but much easier to read for 30 mins.

---

## Common Dark Mode Pitfalls

### Pitfall 1: Invisible dividers
```dart
// ❌ Wrong — default Divider is too visible in dark mode
Divider()

// ✅ Right — use token
Divider(color: AppColors.divider, height: 1, thickness: 1)
```

### Pitfall 2: Borders that fight content
```dart
// ❌ Wrong — high contrast border draws eye away from content
Container(decoration: BoxDecoration(border: Border.all(color: Colors.white)))

// ✅ Right — subtle outline stays in background
Container(decoration: BoxDecoration(
  border: Border.all(color: AppColors.outline, width: 0.5),
))
```

### Pitfall 3: Images with no placeholder
In dark mode, the flash from transparent → loaded image is jarring.
Always use `CachedNetworkImage` with `placeholder` set to `AppColors.surfaceVariant`.

### Pitfall 4: White icons on white-ish backgrounds
When overlaying icons on images, always add scrim first:
```dart
// ❌ Wrong — icon lost against bright image
Icon(Icons.favorite, color: Colors.white)

// ✅ Right — scrim guarantees contrast
Stack(children: [
  image,
  Container(color: AppColors.scrimLight),  // scrim
  Icon(Icons.favorite, color: Colors.white),
])
```

### Pitfall 5: Keyboard covering content
Always wrap forms in `SingleChildScrollView` with:
```dart
resizeToAvoidBottomInset: true  // on Scaffold (default true, but be explicit)
```
And test with keyboard open on a small device.

---

## AppBar Scroll Behavior

In dark mode, the default `scrolledUnderElevation` adds a tint that
looks wrong. Always disable:

```dart
AppBar(
  scrolledUnderElevation: 0,
  surfaceTintColor: Colors.transparent,
  backgroundColor: AppColors.background,
)
```

For feeds that should feel immersive (no visible app bar while scrolling):
```dart
SliverAppBar(
  floating: true,     // reappears when scrolling up
  snap: true,         // snaps fully open/closed
  elevation: 0,
  backgroundColor: AppColors.background,
)
```

---

## Bottom Navigation Bar

The nav bar should be a distinct layer above content, not blending in:
```dart
NavigationBar(
  backgroundColor: AppColors.surface,    // one step above background
  surfaceTintColor: Colors.transparent,
  shadowColor: Colors.black,
  elevation: 8,                          // shadow gives depth, not tint
)
```

Add a top border to visually separate from content:
```dart
// Wrap NavigationBar in:
DecoratedBox(
  decoration: const BoxDecoration(
    border: Border(top: BorderSide(color: AppColors.outline, width: 0.5)),
  ),
  child: NavigationBar(...),
)
```

---

## Image Aspect Ratios for Social Content

| Content type | Ratio | Notes |
|---|---|---|
| Profile avatar | 1:1 | Always circular |
| Post single image | 4:5 | Portrait-optimised (Instagram standard) |
| Post landscape | 16:9 | For wide photos |
| Post square | 1:1 | Grid display |
| Post grid thumbnail | 1:1 | Always square in grid |
| Story / reel | 9:16 | Full screen portrait |

Use `AspectRatio` widget to enforce:
```dart
AspectRatio(
  aspectRatio: 4 / 5,
  child: AppNetworkImage(url: post.imageUrl, fit: BoxFit.cover),
)
```
