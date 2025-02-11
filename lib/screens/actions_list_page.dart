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

class _ActionsListPageState extends State<ActionsListPage> {
  List<RobotAction> filteredActions = [];
  List<RobotAction> selectedActions = [];
  TextEditingController searchController = TextEditingController();
  String selectedFilter = 'ID croissant';
  bool isSelecting = false;

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
    loadActions();
  }

  Future<void> saveActions() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> actionsJson = filteredActions.map((action) => jsonEncode(action.toJson())).toList();
    await prefs.setStringList('actions', actionsJson);
  }

  Future<void> loadActions() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? actionsJson = prefs.getStringList('actions');

    if (actionsJson != null) {
      setState(() {
        filteredActions = actionsJson.map((json) => RobotAction.fromJson(jsonDecode(json))).toList();
        widget.actions.clear();
        widget.actions.addAll(filteredActions);
      });
      applyFilter(selectedFilter); // Appliquer le filtre après le chargement
    }
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
      saveActions(); // Sauvegarder après le tri
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
                  filteredActions.remove(action);
                  widget.actions.remove(action);
                });
                saveActions(); // Sauvegarder après suppression
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Action supprimée : ${action.description}')),
                );
                Navigator.of(context).pop();
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
          content: Text('Êtes-vous sûr de vouloir supprimer ces actions ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  filteredActions.removeWhere((action) => selectedActions.contains(action));
                  widget.actions.removeWhere((action) => selectedActions.contains(action));
                  selectedActions.clear();
                });
                saveActions(); // Sauvegarder après suppression multiple
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Actions supprimées !')));
                Navigator.of(context).pop();
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
      selectedActions.clear();
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
      appBar: AppBar(
        title: Text('Liste des Actions'),
        actions: [
          if (isSelecting)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                if (selectedActions.isNotEmpty) {
                  deleteSelectedActions();
                }
              },
            ),
          if (isSelecting)
            IconButton(
              icon: Icon(Icons.check),
              onPressed: endSelectionMode,
            ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(labelText: 'Recherche...'),
                  onChanged: (value) {
                    String query = value.toLowerCase();
                    setState(() {
                      filteredActions = widget.actions.where((action) {
                        return action.id.toString().contains(query) ||
                            action.description.toLowerCase().contains(query);
                      }).toList();
                      applyFilter(selectedFilter); // Réappliquer le filtre après recherche
                    });
                  },
                ),
              ),
              DropdownButton<String>(
                value: selectedFilter,
                items: filterOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    applyFilter(newValue);
                  }
                },
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredActions.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onLongPress: () {
                    startSelectionMode();
                    toggleSelection(filteredActions[index]);
                  },
                  child: ListTile(
                    title: Text('ID: ${filteredActions[index].id} - ${filteredActions[index].description}'),
                    subtitle: Text(filteredActions[index].time),
                    tileColor: selectedActions.contains(filteredActions[index]) ? Colors.blue[100] : null,
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => deleteAction(filteredActions[index]),
                    ),
                    onTap: () {
                      if (!isSelecting) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActionDetailPage(action: filteredActions[index]),
                          ),
                        );
                      } else {
                        toggleSelection(filteredActions[index]);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: IconButton(
          icon: Icon(Icons.refresh),
          onPressed: () async {
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
                      onPressed: () async {
                        setState(() {
                          filteredActions.clear();
                          widget.actions.clear();
                        });
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('actions'); // Réinitialisation
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Liste des actions réinitialisée !')));
                        Navigator.of(context).pop();
                      },
                      child: Text('Réinitialiser'),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
