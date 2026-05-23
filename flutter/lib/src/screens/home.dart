import 'package:flutter/material.dart';
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

  void _openAdd() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('New Entry')),
        body: AddScreen(onAdded: () => Navigator.pop(context)),
      ),
    )).then((_) => setState(() {}));
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
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: FilledButton.icon(
            onPressed: _openAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Entry'),
          ),
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
      trailing: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton.small(
          heroTag: 'add', onPressed: _openAdd, child: const Icon(Icons.add)),
      ),
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
      // Permanent sidebar
      return Scaffold(
        body: Row(children: [
          _buildRail(),
          const VerticalDivider(width: 1),
          Expanded(child: _buildPage()),
        ]),
        floatingActionButton: null,
      );
    }

    // Drawer on narrow screens
    return Scaffold(
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
