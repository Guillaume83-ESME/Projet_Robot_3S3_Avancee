import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/robot_action.dart';
import 'action_detail_page.dart';

class ActionsListPage extends StatefulWidget {
  final List<RobotAction> actions;

  ActionsListPage({required this.actions});

  @override
  _ActionsListPageState createState() => _ActionsListPageState();
}

class _ActionsListPageState extends State<ActionsListPage> with SingleTickerProviderStateMixin {
  List<RobotAction> filteredActions = [];
  List<RobotAction> selectedActions = [];
  TextEditingController searchController = TextEditingController();
  String selectedFilter = 'ID croissant';
  bool isSelecting = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  final List<String> filterOptions = [
    'ID croissant',
    'ID décroissant',
    'Nom A-Z',
    'Nom Z-A',
    'Date récente',
    'Date ancienne',
  ];

  @override
  void initState() {
    super.initState();
    filteredActions = widget.actions;
    loadActions();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadActions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('actions');
    if (jsonString != null) {
      final jsonList = json.decode(jsonString) as List<dynamic>;
      setState(() {
        widget.actions.clear(); // Clear existing actions
        widget.actions.addAll(jsonList.map((e) => RobotAction.fromJson(e)).toList());
        filteredActions = List.from(widget.actions); // Create a new list
      });
    }
  }

  Future<void> saveActions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(widget.actions.map((e) => e.toJson()).toList());
    await prefs.setString('actions', jsonString);
  }

  void applyFilter(String filter) {
    setState(() {
      selectedFilter = filter;
      switch (filter) {
        case 'ID croissant':
          filteredActions.sort((a, b) => a.id.compareTo(b.id));
          break;
        case 'ID décroissant':
          filteredActions.sort((a, b) => b.id.compareTo(a.id));
          break;
        case 'Nom A-Z':
          filteredActions.sort((a, b) => a.description.compareTo(b.description));
          break;
        case 'Nom Z-A':
          filteredActions.sort((a, b) => b.description.compareTo(a.description));
          break;
        case 'Date récente':
          filteredActions.sort((a, b) => b.time.compareTo(a.time));
          break;
        case 'Date ancienne':
          filteredActions.sort((a, b) => a.time.compareTo(b.time));
          break;
      }
    });
  }

  void deleteAction(RobotAction action) {
    setState(() {
      widget.actions.remove(action);
      filteredActions.remove(action);
      saveActions();
    });
  }

  void deleteSelectedActions() {
    setState(() {
      widget.actions.removeWhere((action) => selectedActions.contains(action));
      filteredActions.removeWhere((action) => selectedActions.contains(action));
      selectedActions.clear();
      isSelecting = false;
      saveActions();
    });
  }

  void toggleSelection(RobotAction action) {
    setState(() {
      if (selectedActions.contains(action)) {
        selectedActions.remove(action);
      } else {
        selectedActions.add(action);
      }
    });
  }

  void startSelectionMode() {
    setState(() {
      isSelecting = true;
    });
  }

  void endSelectionMode() {
    setState(() {
      isSelecting = false;
      selectedActions.clear();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildSearchAndFilter(),
              Expanded(child: _buildActionsList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showResetConfirmation,
        child: Icon(Icons.refresh),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Liste des Actions',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 10.0,
                  color: Colors.black.withOpacity(0.3),
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (isSelecting)
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.white),
                  onPressed: () {
                    if (selectedActions.isNotEmpty) {
                      deleteSelectedActions();
                    }
                  },
                ),
              IconButton(
                icon: Icon(isSelecting ? Icons.close : Icons.select_all, color: Colors.white),
                onPressed: isSelecting ? endSelectionMode : startSelectionMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Recherche...',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              prefixIcon: Icon(Icons.search, color: Colors.white70),
            ),
            style: TextStyle(color: Colors.white),
            onChanged: _onSearchChanged,
          ),
          SizedBox(height: 8),
          DropdownButton<String>(
            value: selectedFilter,
            items: filterOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                applyFilter(newValue);
              }
            },
            dropdownColor: Color(0xFF3949AB),
            style: TextStyle(color: Colors.white),
            icon: Icon(Icons.arrow_drop_down, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsList() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ListView.builder(
          itemCount: filteredActions.length,
          itemBuilder: (context, index) {
            final action = filteredActions[index];
            return FadeTransition(
              opacity: _animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    index / filteredActions.length,
                    (index + 1) / filteredActions.length,
                    curve: Curves.easeOut,
                  ),
                )),
                child: _buildActionCard(action),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionCard(RobotAction action) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _onActionTap(action),
        onLongPress: () => _onActionLongPress(action),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selectedActions.contains(action)
                  ? [Colors.blue.withOpacity(0.7), Colors.blue]
                  : [Colors.white, Colors.white70],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            title: Text(
              'ID: ${action.id} - ${action.description}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(action.time),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => deleteAction(action),
            ),
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    String query = value.toLowerCase();
    setState(() {
      filteredActions = widget.actions.where((action) {
        return action.id.toString().contains(query) ||
            action.description.toLowerCase().contains(query);
      }).toList();
      applyFilter(selectedFilter);
    });
  }

  void _onActionTap(RobotAction action) {
    if (!isSelecting) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActionDetailPage(action: action),
        ),
      );
    } else {
      toggleSelection(action);
    }
  }

  void _onActionLongPress(RobotAction action) {
    if (!isSelecting) {
      startSelectionMode();
    }
    toggleSelection(action);
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Êtes-vous sûr de vouloir réinitialiser la liste des actions ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: _resetActions,
              child: Text('Réinitialiser'),
            ),
          ],
        );
      },
    );
  }

  void _resetActions() async {
    setState(() {
      filteredActions.clear();
      widget.actions.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('actions');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Liste des actions réinitialisée !')),
    );
    Navigator.of(context).pop();
  }
}

