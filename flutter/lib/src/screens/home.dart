import 'dart:io';
import 'package:flutter/material.dart';
import '../../main.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openAdd() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('New Entry')),
        body: AddScreen(onAdded: () => Navigator.pop(context)),
      ),
    )).then((_) => setState(() {}));
  }

  Future<void> _showExportDialog() async {
    final ctrl = TextEditingController(text: '${Platform.environment['HOME']}/sift-export.jsonl');
    final r = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Export Entries'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(
        labelText: 'File path', border: OutlineInputBorder(),
        helperText: '.jsonl .json .md')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Export')),
      ],
    ));
    if (r == null || r.isEmpty) return;
    try {
      await siftService.exportTo(r);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $r'), duration: const Duration(seconds: 2)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _showImportDialog() async {
    final ctrl = TextEditingController(text: '${Platform.environment['HOME']}/sift-import.jsonl');
    final r = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Import Entries'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(
        labelText: 'File path', border: OutlineInputBorder(),
        helperText: '.jsonl (merge by default)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Import')),
      ],
    ));
    if (r == null || r.isEmpty) return;
    try {
      final count = await siftService.importFrom(r);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $count entries'), duration: const Duration(seconds: 2)));
        setState(() {});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Widget _buildNavDrawer() {
    return NavigationDrawer(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 20, 16, 12),
          child: Text('sift', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        const Divider(),
        NavigationDrawerDestination(
          icon: Icon(_selectedIndex == 0 ? Icons.inbox : Icons.inbox_outlined),
          label: const Text('Inbox'),
        ),
        NavigationDrawerDestination(
          icon: Icon(_selectedIndex == 1 ? Icons.tag : Icons.tag_outlined),
          label: const Text('Tags'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: FilledButton.icon(
            onPressed: _openAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Entry'),
          ),
        ),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            OutlinedButton.icon(onPressed: _showExportDialog, icon: const Icon(Icons.upload, size: 16), label: const Text('Export')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _showImportDialog, icon: const Icon(Icons.download, size: 16), label: const Text('Import')),
          ]),
        ),
      ],
    );
  }

  Widget _buildRail() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.85,
      leading: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text('sift', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary)),
      ),
      trailing: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.small(heroTag: 'add', onPressed: _openAdd, child: const Icon(Icons.add)),
        const SizedBox(height: 8),
        IconButton(icon: const Icon(Icons.upload, size: 18), tooltip: 'Export', onPressed: _showExportDialog),
        IconButton(icon: const Icon(Icons.download, size: 18), tooltip: 'Import', onPressed: _showImportDialog),
        const SizedBox(height: 8),
      ]),
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: Text('Inbox')),
        NavigationRailDestination(icon: Icon(Icons.tag_outlined), selectedIcon: Icon(Icons.tag), label: Text('Tags')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    if (isWide) {
      return Scaffold(
        body: Row(children: [
          _buildRail(),
          const VerticalDivider(width: 1),
          Expanded(child: _buildPage()),
        ]),
        floatingActionButton: null,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: Text(_selectedIndex == 0 ? 'Inbox' : 'Tags'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _openAdd),
        ],
      ),
      drawer: _buildNavDrawer(),
      body: _buildPage(),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return ListScreen(tagFilter: _tagFilter, onFilterApplied: () => setState(() => _tagFilter = null));
      case 1:
        return TagsScreen(onTagTap: (tag) {
          _tagFilter = tag;
          _selectedIndex = 0;
          setState(() {});
        });
      default:
        return ListScreen(tagFilter: null, onFilterApplied: () {});
    }
  }
}
