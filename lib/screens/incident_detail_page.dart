import 'package:flutter/material.dart';
import '../models/incident.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class IncidentDetailPage extends StatefulWidget {
  final Incident incident;

  IncidentDetailPage({required this.incident});

  @override
  _IncidentDetailPageState createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<IncidentDetailPage> {
  TextEditingController noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    noteController.text = widget.incident.note ?? ''; // Charger la note existante
  }

  Future<void> saveNote() async {
    setState(() {
      widget.incident.note = noteController.text; // Enregistrer la note dans le modèle
    });

    // Sauvegarder tous les incidents pour mettre à jour SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    List<String>? incidentsJson = prefs.getStringList('incidents');

    if (incidentsJson != null) {
      List<Incident> incidents = incidentsJson.map((json) => Incident.fromJson(jsonDecode(json))).toList();
      // Mettre à jour l'incident modifié dans la liste
      int index = incidents.indexWhere((i) => i.id == widget.incident.id);
      if (index != -1) {
        incidents[index] = widget.incident; // Remplacer l'incident modifié
      }
      // Sauvegarder la liste mise à jour
      await prefs.setStringList('incidents', incidents.map((incident) => jsonEncode(incident.toJson())).toList());
    }

    Navigator.of(context).pop(); // Fermer la page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Note enregistrée: ${widget.incident.note}')),
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
              onPressed: () => Navigator.of(context).pop(), // Fermer le dialog sans enregistrer
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
        title: Text('Détails de l\'Incident'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${widget.incident.id}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Description: ${widget.incident.description}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Heure: ${widget.incident.time}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            if (widget.incident.note != null && widget.incident.note!.isNotEmpty) ...[
              Text('Note:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text(widget.incident.note!, style: TextStyle(fontSize: 16)),
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
