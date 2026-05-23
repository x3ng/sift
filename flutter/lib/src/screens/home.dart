import 'package:flutter/material.dart';
import 'list_screen.dart';
import 'add_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final List<String> _activeFilters = [];
  String? _dueFilter;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 600;

    if (isWide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.list), label: Text('List')),
              NavigationRailDestination(icon: Icon(Icons.add_circle_outline), label: Text('Add')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _buildPage()),
        ]),
      );
    }

    return Scaffold(
      body: _buildPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list), label: 'List'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Add'),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return ListScreen(filters: _activeFilters, dueFilter: _dueFilter);
      case 1:
        return AddScreen(onAdded: () => setState(() => _selectedIndex = 0));
      default:
        return const ListScreen(filters: [], dueFilter: null);
    }
  }
}
