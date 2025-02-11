import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/command.dart';
import 'command_detail_page.dart';

class CommandListPage extends StatefulWidget {
  final List<Command> commands;

  CommandListPage({required this.commands});

  @override
  _CommandListPageState createState() => _CommandListPageState();
}

class _CommandListPageState extends State<CommandListPage> {
  List<Command> filteredCommands = [];
  List<Command> selectedCommands = [];
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
    loadCommands();
  }

  Future<void> saveCommands() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> commandsJson = filteredCommands.map((command) => jsonEncode(command.toJson())).toList();
    await prefs.setStringList('commands', commandsJson);
  }

  Future<void> loadCommands() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? commandsJson = prefs.getStringList('commands');

    if (commandsJson != null) {
      setState(() {
        filteredCommands = commandsJson.map((json) => Command.fromJson(jsonDecode(json))).toList();
        widget.commands.clear();
        widget.commands.addAll(filteredCommands);
      });
      applyFilter(selectedFilter); // Apply the filter after loading
    }
  }

  void applyFilter(String filter) {
    setState(() {
      selectedFilter = filter;
      switch (filter) {
        case 'ID croissant':
          filteredCommands.sort((a, b) => a.id.compareTo(b.id));
          break;
        case 'ID décroissant':
          filteredCommands.sort((a, b) => b.id.compareTo(a.id));
          break;
        case 'Nom A-Z':
          filteredCommands.sort((a, b) => a.action.compareTo(b.action));
          break;
        case 'Nom Z-A':
          filteredCommands.sort((a, b) => b.action.compareTo(a.action));
          break;
        case 'Date récente':
          filteredCommands.sort((a, b) => b.time.compareTo(a.time));
          break;
        case 'Date ancienne':
          filteredCommands.sort((a, b) => a.time.compareTo(b.time));
          break;
      }
      saveCommands(); // Save after applying filter
    });
  }

  void deleteCommand(Command command) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Êtes-vous sûr de vouloir supprimer cette commande ?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  filteredCommands.remove(command);
                  widget.commands.remove(command);
                });
                saveCommands(); // Save changes after deletion
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Commande supprimée : ${command.action}')),
                );
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  void deleteSelectedCommands() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Êtes-vous sûr de vouloir supprimer ces commandes ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  filteredCommands.removeWhere((command) => selectedCommands.contains(command));
                  widget.commands.removeWhere((command) => selectedCommands.contains(command));
                  selectedCommands.clear();
                });
                saveCommands(); // Save changes after bulk deletion
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Commandes supprimées !')));
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  void toggleSelection(Command command) {
    setState(() {
      if (selectedCommands.contains(command)) {
        selectedCommands.remove(command);
      } else {
        selectedCommands.add(command);
      }
    });
  }

  void startSelectionMode() {
    setState(() {
      isSelecting = true;
      selectedCommands.clear();
    });
  }

  void endSelectionMode() {
    setState(() {
      isSelecting = false;
      selectedCommands.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Liste des Commandes'),
        actions: [
          if (isSelecting)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                if (selectedCommands.isNotEmpty) {
                  deleteSelectedCommands();
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
                      filteredCommands = widget.commands.where((command) {
                        return command.id.toString().contains(query) || command.action.toLowerCase().contains(query);
                      }).toList();
                      applyFilter(selectedFilter); // Reapply filter after search
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
              itemCount: filteredCommands.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onLongPress: () {
                    startSelectionMode();
                    toggleSelection(filteredCommands[index]);
                  },
                  child: ListTile(
                    title: Text('ID: ${filteredCommands[index].id} - ${filteredCommands[index].action}'),
                    subtitle: Text(filteredCommands[index].time),
                    tileColor: selectedCommands.contains(filteredCommands[index]) ? Colors.blue[100] : null,
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => deleteCommand(filteredCommands[index]), // Call delete with confirmation
                    ),
                    onTap: () {
                      if (!isSelecting) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CommandDetailPage(command: filteredCommands[index])),
                        );
                      } else {
                        toggleSelection(filteredCommands[index]);
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
                  content: Text('Êtes-vous sûr de vouloir réinitialiser la liste des commandes ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () async {
                        setState(() {
                          filteredCommands.clear();
                          widget.commands.clear();
                        });
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('commands'); // Clear stored commands
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Liste des commandes réinitialisée !')));
                        Navigator.of(context).pop(); // Close the dialog
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
