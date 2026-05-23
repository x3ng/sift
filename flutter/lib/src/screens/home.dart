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
  final _listKey = GlobalKey();

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

    if (isWide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            trailing: Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                FloatingActionButton.small(
                  heroTag: 'add',
                  onPressed: _openAdd,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 12),
              ]),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: Text('Inbox')),
              NavigationRailDestination(icon: Icon(Icons.tag_outlined), selectedIcon: Icon(Icons.tag), label: Text('Tags')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _buildPage()),
        ]),
      );
    }

    return Scaffold(
      body: _buildPage(),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(onPressed: _openAdd, child: const Icon(Icons.add))
          : null,
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return ListScreen(key: _listKey);
      case 1:
        return const TagsScreen();
      default:
        return ListScreen(key: _listKey);
    }
  }
}
