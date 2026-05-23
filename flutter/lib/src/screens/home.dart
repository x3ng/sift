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
  String? _tagFilter; // from tags page: filter inbox by this tag

  void _openAdd() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('New Entry')),
        body: AddScreen(onAdded: () => Navigator.pop(context)),
      ),
    )).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      body: Row(children: [
        // Sidebar — NavigationRail on all sizes
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          labelType: isWide ? NavigationRailLabelType.all : NavigationRailLabelType.selected,
          groupAlignment: -0.85,
          trailing: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FloatingActionButton.small(
              heroTag: 'add',
              onPressed: _openAdd,
              child: const Icon(Icons.add),
            ),
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.inbox_outlined),
              selectedIcon: Icon(Icons.inbox),
              label: Text('Inbox'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.tag_outlined),
              selectedIcon: Icon(Icons.tag),
              label: Text('Tags'),
            ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _buildPage()),
      ]),
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
