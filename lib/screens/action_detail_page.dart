import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/robot_action.dart';

class ActionDetailPage extends StatefulWidget {
  final RobotAction action;

  ActionDetailPage({required this.action});

  @override
  _ActionDetailPageState createState() => _ActionDetailPageState();
}

class _ActionDetailPageState extends State<ActionDetailPage> {
  TextEditingController noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadNote();
  }

  Future<void> loadNote() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'action_note_${widget.action.id}';
    final savedNote = prefs.getString(key);

    if (savedNote != null) {
      setState(() {
        widget.action.note = savedNote;
        noteController.text = savedNote;
      });
    }
  }

  Future<void> saveNote() async {
    setState(() {
      widget.action.note = noteController.text;
    });

    // Sauvegarder la note dans SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final key = 'action_note_${widget.action.id}';
    await prefs.setString(key, widget.action.note ?? '');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Note enregistrée: ${widget.action.note}')),
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
              onPressed: () async {
                await saveNote();
                Navigator.of(context).pop();
              },
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
        title: Text('Détails de l\'Action'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${widget.action.id}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Description: ${widget.action.description}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Heure: ${widget.action.time}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            if (widget.action.note != null && widget.action.note!.isNotEmpty) ...[
              Text('Note:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text(widget.action.note!, style: TextStyle(fontSize: 16)),
              SizedBox(height: 20),
            ],
            ElevatedButton(
              onPressed: showAddNoteDialog,
              child: Text('Ajouter une note'),
            ),
          ],
        ),
      ),
    );
  }
}
