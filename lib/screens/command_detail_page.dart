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
    noteController.text = widget.command.note ?? ''; // Load existing note
  }

  Future<void> saveNote() async {
    setState(() {
      widget.command.note = noteController.text; // Save note in the model
    });

    // Save updated command list to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    List<String> commandsJson = await prefs.getStringList('commands') ?? [];
    List<Command> commands = commandsJson.map((json) => Command.fromJson(jsonDecode(json))).toList();

    // Update the specific command in the list
    int index = commands.indexWhere((cmd) => cmd.id == widget.command.id);
    if (index != -1) {
      commands[index] = widget.command; // Update the command with the new note
    }

    // Save back to SharedPreferences
    await prefs.setStringList('commands', commands.map((cmd) => jsonEncode(cmd.toJson())).toList());

    Navigator.of(context).pop(); // Close the dialog
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
              onPressed: () => Navigator.of(context).pop(), // Close dialog without saving
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
      appBar: AppBar(
        title: Text('Détails de la Commande'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
              Text(widget.command.note!, style: TextStyle(fontSize: 16)),
              SizedBox(height: 20),
            ],
            ElevatedButton(
              onPressed: showAddNoteDialog,
              child:
              const Text('Ajouter une note'),
            ),
          ],
        ),
      ),
    );
  }
}
