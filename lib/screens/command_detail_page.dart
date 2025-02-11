import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/command.dart';

class CommandDetailPage extends StatefulWidget {
  final Command command;

  CommandDetailPage({required this.command});

  @override
  _CommandDetailPageState createState() => _CommandDetailPageState();
}

class _CommandDetailPageState extends State<CommandDetailPage> {
  TextEditingController noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    noteController.text = widget.command.note ?? '';
  }

  Future<void> saveNote() async {
    setState(() {
      widget.command.note = noteController.text;
    });

    final prefs = await SharedPreferences.getInstance();
    List<String> commandsJson = await prefs.getStringList('commands') ?? [];
    List<Command> commands = commandsJson.map((json) => Command.fromJson(jsonDecode(json))).toList();

    int index = commands.indexWhere((cmd) => cmd.id == widget.command.id);
    if (index != -1) {
      commands[index] = widget.command;
    }

    await prefs.setStringList('commands', commands.map((cmd) => jsonEncode(cmd.toJson())).toList());

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Note enregistrée: ${widget.command.note}')),
    );
  }

  void showAddNoteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Ajouter une note"),
          content: TextField(
            controller: noteController,
            decoration: InputDecoration(labelText: 'Entrez votre note ici'),
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Annuler"),
            ),
            TextButton(
              onPressed: saveNote,
              child: Text("Enregistrer"),
            ),
          ],
        );
      },
    );
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      'Détails de la Commande',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID : ${widget.command.id}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        Text('Action : ${widget.command.action}', style: TextStyle(fontSize: 18)),
                        SizedBox(height: 10),
                        Text('Heure : ${widget.command.time}', style: TextStyle(fontSize: 18)),
                        SizedBox(height: 20),
                        if (widget.command.note != null && widget.command.note!.isNotEmpty) ...[
                          Text('Note:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 5),
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(widget.command.note!, style: TextStyle(fontSize: 16)),
                          ),
                          SizedBox(height: 20),
                        ],
                        ElevatedButton(
                          onPressed: showAddNoteDialog,
                          child: Text('Ajouter une note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF3949AB),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

