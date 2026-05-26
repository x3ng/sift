# Flutter GUI architecture

Flutter GUI is a frontend. All logic lives in Rust [SiftCore](core.md) via FFI.

## Structure

```
flutter/lib/
├── main.dart                    # App entry, theme, NativeService singleton
└── src/
    ├── services/
    │   ├── ffi_service.dart     # NativeService: FFI bridge to Rust
    │   └── prefs.dart           # JSON-file preferences (pinned filter)
    ├── screens/
    │   ├── home.dart            # Responsive shell: rail (wide) / drawer (narrow)
    │   ├── list_screen.dart     # Entry list + FilterBar + batch ops
    │   ├── detail_screen.dart   # View/edit entry, tag management
    │   ├── add_screen.dart      # New entry form
    │   └── tags_screen.dart     # All tags browser
    └── widgets/
        ├── filter_bar.dart      # Thin wrapper around TagCombinator
        ├── tag_combinator.dart  # Search/tagging input with autocomplete
        ├── entry_card.dart      # Entry list item
        └── tag_chips.dart       # Tag chip display
```

## FFI bridge

`NativeService` in `ffi_service.dart` wraps 17 C functions from `libsift_ffi.so`.
All communication is JSON-based: Dart encodes args as JSON strings, Rust returns JSON strings.

Data models (`FrbEntry`, `FrbBody`, `FrbParsedQuery`, etc.) are defined in ffi_service.dart.

## State management

Pure `setState`. No external state management package.
Communication between screens via callbacks and Navigator results.

## Responsive layout

- Wide (>=600px): collapsible sidebar rail (48px/160px) + content
- Narrow: drawer + bottom navigation bar

## Theme

Material 3, seed color `#556B7A` (light) / `#8BA1AE` (dark).

## Platform targets

Linux, macOS, Windows, Android. No iOS FFI path yet.

## Dependencies

ffi, file_picker, path_provider
