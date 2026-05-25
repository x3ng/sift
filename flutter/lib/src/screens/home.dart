import 'dart:io';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../services/ffi_service.dart';
import 'list_screen.dart';
import 'add_screen.dart';
import 'tags_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _tagFilter;
  String? _activeViewName;
  var _reloadKey = 0;
  bool _railOpen = true;
  List<FrbEntry> _views = [];

  @override
  void initState() {
    super.initState();
    _loadViews();
  }

  Future<void> _loadViews() async {
    try {
      final views = await siftService.getViews();
      if (mounted) setState(() => _views = views);
    } catch (_) {}
  }

  void _openAdd() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('New Entry')),
        body: AddScreen(onAdded: () => Navigator.pop(context)),
      ),
    )).then((_) { setState(() => _reloadKey++); _loadViews(); });
  }

  Future<void> _showExportDialog() async {
    final ctrl = TextEditingController(text: '${Platform.environment['HOME']}/sift-export.jsonl');
    final r = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Export'), content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Path', border: OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Export'))],
    ));
    if (r == null || r.isEmpty) return;
    try { await siftService.exportTo(r); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> _showImportDialog() async {
    final ctrl = TextEditingController(text: '${Platform.environment['HOME']}/sift-import.jsonl');
    final r = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Import'), content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Path', border: OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Import'))],
    ));
    if (r == null || r.isEmpty) return;
    try { final c = await siftService.importFrom(r); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $c entries'))); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  // ── sidebar ──────────────────────────────────────────────────

  Widget _buildRail() {
    final cs = Theme.of(context).colorScheme;
    final w = _railOpen ? 160.0 : 48.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: w,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withAlpha(isDark ? 60 : 40),
        border: Border(right: BorderSide(color: cs.outlineVariant.withAlpha(40))),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        InkWell(
          onTap: () => setState(() => _railOpen = !_railOpen),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(children: [
              Icon(_railOpen ? Icons.menu_open_rounded : Icons.menu_rounded, size: 22, color: cs.onSurface.withAlpha(120)),
              if (_railOpen) ...[const SizedBox(width: 10), const Text('sift', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))],
            ]),
          ),
        ),
        const SizedBox(height: 8),
        _railNav(Icons.inbox_rounded, 'All', 0),
        _railNav(Icons.tag_rounded, 'Tags', 1),
        if (_views.isNotEmpty) ...[
          const SizedBox(height: 8),
          if (_railOpen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [Text('Views', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.outline.withAlpha(120)))],),
            ),
          for (final v in _views)
            _viewTab(v),
        ],
        const Spacer(),
        _railAction(Icons.add_circle_outline_rounded, 'Add', _openAdd),
        _railAction(Icons.upload_rounded, 'Export', _showExportDialog),
        _railAction(Icons.download_rounded, 'Import', _showImportDialog),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _railNav(IconData icon, String label, int index) {
    final cs = Theme.of(context).colorScheme;
    final active = _selectedIndex == index;
    return Tooltip(
      message: _railOpen ? '' : label,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: () => setState(() { _selectedIndex = index; _activeViewName = null; }),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
          child: Row(children: [
            Icon(icon, size: 22, color: active ? cs.primary : cs.onSurface.withAlpha(100)),
            if (_railOpen) ...[const SizedBox(width: 10), Text(label, style: TextStyle(fontSize: 13.5, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? cs.primary : cs.onSurface.withAlpha(200)))],
          ]),
        ),
      ),
    );
  }

  Widget _railAction(IconData icon, String label, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: _railOpen ? '' : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(children: [
            Icon(icon, size: 20, color: cs.onSurface.withAlpha(100)),
            if (_railOpen) ...[const SizedBox(width: 10), Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface.withAlpha(160)))],
          ]),
        ),
      ),
    );
  }

  Widget _viewTab(FrbEntry view) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: _railOpen ? '' : view.name,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: () {
          setState(() { _selectedIndex = -1; _activeViewName = view.name; _reloadKey++; });
          _tagFilter = view.body.text;
        },
        onLongPress: () async {
          final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
            title: Text('Delete view "${view.name}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ));
          if (ok == true) { await siftService.deleteView(view.id); _loadViews(); }
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(children: [
            Icon(Icons.bookmark_rounded, size: 18, color: cs.primary.withAlpha(180)),
            if (_railOpen) ...[const SizedBox(width: 10), Expanded(child: Text(view.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))],
          ]),
        ),
      ),
    );
  }

  // ── phone ────────────────────────────────────────────────────

  Widget _buildPhoneBottomBar() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant.withAlpha(50)))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _bottomTab(Icons.inbox_rounded, 'All', 0),
            _bottomTab(Icons.tag_rounded, 'Tags', 1),
          ]),
        ),
      ),
    );
  }

  Widget _bottomTab(IconData icon, String label, int index) {
    final cs = Theme.of(context).colorScheme;
    final active = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 24, color: active ? cs.primary : cs.onSurface.withAlpha(100)),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? cs.primary : cs.onSurface.withAlpha(130))),
        ]),
      ),
    );
  }

  // ── build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    if (isWide) {
      return Scaffold(
        body: Row(children: [
          _buildRail(),
          const VerticalDivider(width: 0),
          Expanded(child: SafeArea(child: _buildPage())),
        ]),
      );
    }

    // Narrow: hamburger → drawer
    final title = _activeViewName ?? (_selectedIndex == 0 ? 'All' : 'Tags');
    final icon = _activeViewName != null ? Icons.bookmark_rounded
        : _selectedIndex == 0 ? Icons.inbox_rounded
        : Icons.tag_rounded;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 46,
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu, size: 20),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: Row(children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.add, size: 22), onPressed: _openAdd),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 22),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'export', child: Text('Export')),
              const PopupMenuItem(value: 'import', child: Text('Import')),
            ],
            onSelected: (v) { if (v == 'export') _showExportDialog(); if (v == 'import') _showImportDialog(); },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildPage(),
    );
  }

  Widget _buildDrawer() {
    return NavigationDrawer(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) {
        setState(() { _selectedIndex = i; _activeViewName = null; });
        Navigator.pop(context);
      },
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 20, 16, 12),
          child: Text('sift', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        const Divider(),
        const NavigationDrawerDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox_rounded), label: Text('All')),
        const NavigationDrawerDestination(icon: Icon(Icons.tag_outlined), selectedIcon: Icon(Icons.tag_rounded), label: Text('Tags')),
        if (_views.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 16, 16, 4),
            child: Text('Views', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          for (final v in _views)
            _drawerViewItem(v),
        ],
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: FilledButton.icon(
            onPressed: () { Navigator.pop(context); _openAdd(); },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Entry'),
          ),
        ),
      ],
    );
  }

  Widget _drawerViewItem(FrbEntry view) {
    return ListTile(
      leading: const Icon(Icons.bookmark_rounded, size: 20),
      title: Text(view.name, style: const TextStyle(fontSize: 14)),
      onTap: () {
        setState(() { _selectedIndex = -1; _activeViewName = view.name; _reloadKey++; });
        _tagFilter = view.body.text;
        Navigator.pop(context);
      },
      onLongPress: () async {
        Navigator.pop(context);
        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: Text('Delete view "${view.name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ));
        if (ok == true) { await siftService.deleteView(view.id); _loadViews(); }
      },
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case -1: // View tab
      case 0:
        return ListScreen(key: ValueKey(_reloadKey), tagFilter: _tagFilter, onFilterApplied: () {
          setState(() { _tagFilter = null; _selectedIndex = 0; });
          _loadViews();
        });
      case 1:
        return TagsScreen(onTagTap: (tag) { _tagFilter = tag; _selectedIndex = 0; setState(() => _reloadKey++); });
      default:
        return ListScreen(key: ValueKey(_reloadKey), tagFilter: null, onFilterApplied: () {});
    }
  }
}
