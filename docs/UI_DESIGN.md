# sift — UI design

## Design philosophy

sift's GUI is a **tag-oriented list browser**, not a traditional app with pages and menus. The combinator search bar is the primary interaction surface — everything flows from it.

### Core principles

- **The filter IS the interface.** No navigation takes priority over the current filter state.
- **List-first.** Entries are the content; everything else is scaffolding.
- **Minimal chrome.** Default Material components are suppressed in favor of custom, lighter renderings.
- **Responsive but consistent.** Wide screens get a permanent rail; narrow screens get a drawer. Same content, different access pattern.

## Layout

```
Wide (>=600px)                     Narrow (<600px)
┌─────┬─────────────────────┐      ┌──────────────────────┐
│ ☰ → │ #urgent -#done  [📌][🔖]│      │ ☰  All         +  ⋮  │  46px
│ All │ ──────────────────── │      ├──────────────────────┤
│ Tag │  Entry one           │      │ #urgent  [📌][🔖]   │  FilterBar
│     │  Entry two           │      │ ──────────────────── │
│ ⭐  │  Entry three         │      │  Entry one           │
│ ⭐  │                      │      │  Entry two           │
│     │                      │      │  Entry three         │
│  +  │                      │      │                      │
│  ⬆  │                      │      │                      │
│  ⬇  │                      │      └──────────────────────┘
└─────┴─────────────────────┘
```

### Sidebar (wide)

- 48px collapsed, 160px expanded
- ☰ toggles expand/collapse
- "All" and "Tags" as permanent nav items
- Saved views appear below with bookmark icon
- Bottom section: Add, Export, Import

### Drawer (narrow)

- Standard Material NavigationDrawer
- "All" and "Tags" as NavigationDrawerDestination
- Saved views as ListTile with bookmark icon
- "New Entry" FilledButton at bottom

### AppBar (narrow only)

- 46px toolbarHeight (slightly shorter than default 56px)
- Dynamic title: shows "All", "Tags", or the active view name
- Hamburger → drawer
- Add button + overflow menu (Export/Import)

## Component design

### FilterBar / TagCombinator

The centerpiece. A single TextField with:
- No border (InputBorder.none), subtle background container
- isDense for compact vertical rhythm
- Chip display below when filters are active
- Pin (📌) and Save-as-View (🔖) actions in trailing slot
- Suggestions dropdown on focus

**Chip colors:**
- AND tag: primaryContainer background
- OR tag: tertiaryContainer background
- NOT tag: error color text
- Date clause: stored as `prefix:period` string, displayed as AND chip

### Entry cards

Custom rendering — no Material Card wrapper:
- 0 elevation, transparent background
- Name: 14.5px, w500, dark/light adaptive alpha
- Done entries: strikethrough + muted color
- File entries: attach icon in top-right
- Tags: custom container chips (not Material Chip)
- Body preview: 13px, 2-line clamp, muted

### Tag chips

Custom Container-based rendering instead of Material Chip:
- 4px border radius, compact padding
- Date tags: tertiaryContainer background
- Regular tags: surfaceContainerHighest background
- `#tagname` format, 11px

## Color system

Material 3 via `ColorScheme.fromSeed`:
- Light: seed `#556B7A` (muted steel blue)
- Dark: seed `#8BA1AE` (lighter steel blue)

Avoids generic purple/AI aesthetic. Monochrome base with steel-blue accent.

## Filter-as-tabs (Named Views)

Users can save the current combinator filter as a named "view" that persists as a sidebar/drawer tab.

- **Save**: Bookmark icon appears next to pin when filter is active. Opens dialog to name the view.
- **Storage**: Views are regular entries with tag `view` and body = combinator expression.
- **Display**: Appear in sidebar (wide) and drawer (narrow) below "Tags".
- **Activate**: Click to apply filter. View name appears in AppBar title.
- **Delete**: Long-press on view tab → confirmation dialog.

## Responsive behavior

| Breakpoint | Layout | Sidebar |
|---|---|---|
| < 600px | AppBar + Drawer | Hidden, accessible via hamburger |
| >= 600px | Permanent rail | Visible, collapsible (48/160px) |

Phone layout uses SafeArea on content pane; wide layout uses full-height row.
