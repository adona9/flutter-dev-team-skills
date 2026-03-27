# flutter-dev-team

A Claude Code plugin with five skills for Flutter app development. Covers the full workflow from feature design to iOS deployment: architecture, UI, testing, code review, and build pipeline.

The skills are designed to work together. `flutter-context` is the foundation — it establishes project conventions that all other skills inherit. Load it first; the others extend it.

---

## Skills

### `flutter-context` — Project constitution
The foundation skill. Defines the project's tech stack (Flutter + Riverpod + go_router), directory layout, naming conventions, approved packages, and the Ubuntu → Mac Mini → iPhone build pipeline. All other skills depend on this one and must never contradict it.

Load this skill at the start of any Flutter session. It triggers automatically on Flutter/Dart-related keywords.

### `flutter-architect` — Feature scaffolding
Translates product requirements into a concrete, file-ready Flutter feature structure. Enforces a mandatory spec validation step before generating any files — rejects vague or incomplete specs. Produces the full layer stack: entity, repository interface, use case, repository impl, notifier, and screen.

### `ui-builder` — UI components
Builds Flutter UI components following the project's Material 3 design system and dark theme. Generates complete, styled widget code using `AppColors`, `AppSpacing`, and `AppTextStyles` tokens — never hardcoded values.

### `test-writer` — Test generation
Generates complete, runnable Flutter tests: unit (notifiers, use cases, repositories), widget (screens, components), and integration (full user flows). Enforces 80% line coverage as a hard gate. No `// TODO` stubs — every generated test file is fully implemented.

### `pr-review` — Pre-merge quality gate
Runs four deterministic check layers before every commit or push: static analysis (`dart analyze` + format), architecture guard (layer boundary violations, naming rules, forbidden patterns), coverage gate (delegates to `test-writer`), and security scan (hardcoded secrets, non-HTTPS URLs, unsafe permission usage). A fifth adversarial layer has the agent review the diff for edge cases the scripts can't catch.

---

## Skill dependency graph

```
flutter-context  (always loads first)
    ├── flutter-architect
    ├── ui-builder
    ├── test-writer
    └── pr-review  (also depends on test-writer for the coverage gate)
```

---

## Project assumptions

These skills are tuned for a specific setup:

| Property | Value |
|---|---|
| Framework | Flutter (latest stable) |
| State management | Riverpod (`flutter_riverpod`) |
| Navigation | `go_router` |
| Architecture | Repository pattern / Clean Architecture |
| Primary target | iOS (iPhone), min iOS 17.0 |
| Secondary target | Android emulator, min SDK 23 |
| Dev machine | Ubuntu (Linux) |
| Build machine | Mac Mini on LAN (SSH) |
| Test library | `mocktail` |
| Coverage gate | 80% line coverage |

If your setup differs, edit `flutter-context/SKILL.md` — it's the single source of truth that all other skills inherit from.
