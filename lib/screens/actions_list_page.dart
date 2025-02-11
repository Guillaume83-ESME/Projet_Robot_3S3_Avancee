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
  late List<RobotAction> filteredActions;
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
    filteredActions = List.from(widget.actions);
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
        widget.actions.clear();
        widget.actions.addAll(jsonList.map((e) => RobotAction.fromJson(e)).toList());
        filteredActions = List.from(widget.actions);
        applyFilter(selectedFilter);
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
      filteredActions.sort((a, b) {
        switch (filter) {
          case 'ID croissant':
            return a.id.compareTo(b.id);
          case 'ID décroissant':
            return b.id.compareTo(a.id);
          case 'Nom A-Z':
            return a.description.compareTo(b.description);
          case 'Nom Z-A':
            return b.description.compareTo(a.description);
          case 'Date récente':
            return b.time.compareTo(a.time);
          case 'Date ancienne':
            return a.time.compareTo(b.time);
          default:
            return 0;
        }
      });
    });
  }

  void deleteAction(RobotAction action) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Êtes-vous sûr de vouloir supprimer cette action ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.actions.remove(action);
                  filteredActions.remove(action);
                  saveActions();
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Action supprimée')),
                );
              },
              child: Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  void deleteSelectedActions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Êtes-vous sûr de vouloir supprimer les actions sélectionnées ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.actions.removeWhere((action) => selectedActions.contains(action));
                  filteredActions.removeWhere((action) => selectedActions.contains(action));
                  selectedActions.clear();
                  isSelecting = false;
                  saveActions();
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Actions sélectionnées supprimées')),
                );
              },
              child: Text('Supprimer'),
            ),
          ],
        );
      },
    );
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
            colors: Theme.of(context).brightness == Brightness.dark
                ? [Colors.grey[900]!, Colors.grey[800]!]
                : [Color(0xFF1A237E), Color(0xFF3949AB)],
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
            dropdownColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Color(0xFF3949AB),
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
                  ? [Colors.blue[700]!, Colors.blue[500]!]
                  : Theme.of(context).brightness == Brightness.dark
                  ? [Colors.grey[800]!, Colors.grey[700]!]
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            subtitle: Text(
              action.time,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
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

