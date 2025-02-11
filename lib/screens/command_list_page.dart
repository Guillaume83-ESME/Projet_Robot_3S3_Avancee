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

class _CommandListPageState extends State<CommandListPage> with SingleTickerProviderStateMixin {
  late List<Command> filteredCommands;
  List<Command> selectedCommands = [];
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
    filteredCommands = List.from(widget.commands);
    loadCommands();
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

  Future<void> loadCommands() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('commands');
    if (jsonString != null) {
      final jsonList = json.decode(jsonString) as List<dynamic>;
      setState(() {
        widget.commands.clear();
        widget.commands.addAll(jsonList.map((e) => Command.fromJson(e)).toList());
        filteredCommands = List.from(widget.commands);
        applyFilter(selectedFilter);
      });
    }
  }

  Future<void> saveCommands() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(widget.commands.map((e) => e.toJson()).toList());
    await prefs.setString('commands', jsonString);
  }

  void applyFilter(String filter) {
    setState(() {
      selectedFilter = filter;
      filteredCommands.sort((a, b) {
        switch (filter) {
          case 'ID croissant':
            return a.id.compareTo(b.id);
          case 'ID décroissant':
            return b.id.compareTo(a.id);
          case 'Nom A-Z':
            return a.action.compareTo(b.action);
          case 'Nom Z-A':
            return b.action.compareTo(a.action);
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

  void deleteCommand(Command command) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Êtes-vous sûr de vouloir supprimer cette commande ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.commands.remove(command);
                  filteredCommands.remove(command);
                  saveCommands();
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Commande supprimée')),
                );
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
          content: Text('Êtes-vous sûr de vouloir supprimer les commandes sélectionnées ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.commands.removeWhere((command) => selectedCommands.contains(command));
                  filteredCommands.removeWhere((command) => selectedCommands.contains(command));
                  selectedCommands.clear();
                  isSelecting = false;
                  saveCommands();
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Commandes sélectionnées supprimées')),
                );
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
              Expanded(child: _buildCommandsList()),
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
          Expanded(
            child: Text(
              'Liste des Commandes',
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
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (isSelecting)
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.white),
                  onPressed: () {
                    if (selectedCommands.isNotEmpty) {
                      deleteSelectedCommands();
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

  Widget _buildCommandsList() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ListView.builder(
          itemCount: filteredCommands.length,
          itemBuilder: (context, index) {
            final command = filteredCommands[index];
            return FadeTransition(
              opacity: _animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    index / filteredCommands.length,
                    (index + 1) / filteredCommands.length,
                    curve: Curves.easeOut,
                  ),
                )),
                child: _buildCommandCard(command),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCommandCard(Command command) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _onCommandTap(command),
        onLongPress: () => _onCommandLongPress(command),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selectedCommands.contains(command)
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
              'ID: ${command.id} - ${command.action}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            subtitle: Text(
              command.time,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => deleteCommand(command),
            ),
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    String query = value.toLowerCase();
    setState(() {
      filteredCommands = widget.commands.where((command) {
        return command.id.toString().contains(query) ||
            command.action.toLowerCase().contains(query);
      }).toList();
      applyFilter(selectedFilter);
    });
  }

  void _onCommandTap(Command command) {
    if (!isSelecting) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CommandDetailPage(command: command),
        ),
      );
    } else {
      toggleSelection(command);
    }
  }

  void _onCommandLongPress(Command command) {
    if (!isSelecting) {
      startSelectionMode();
    }
    toggleSelection(command);
  }

  void _showResetConfirmation() {
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
              onPressed: _resetCommands,
              child: Text('Réinitialiser'),
            ),
          ],
        );
      },
    );
  }

  void _resetCommands() async {
    setState(() {
      filteredCommands.clear();
      widget.commands.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('commands');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Liste des commandes réinitialisée !')),
    );
    Navigator.of(context).pop();
  }
}

