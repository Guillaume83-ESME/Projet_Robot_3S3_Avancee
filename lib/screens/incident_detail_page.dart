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
    noteController.text = widget.incident.note ?? '';
  }

  Future<void> saveNote() async {
    setState(() {
      widget.incident.note = noteController.text;
    });

    final prefs = await SharedPreferences.getInstance();
    List<String>? incidentsJson = prefs.getStringList('incidents');

    if (incidentsJson != null) {
      List<Incident> incidents = incidentsJson.map((json) => Incident.fromJson(jsonDecode(json))).toList();
      int index = incidents.indexWhere((i) => i.id == widget.incident.id);
      if (index != -1) {
        incidents[index] = widget.incident;
      }
      await prefs.setStringList('incidents', incidents.map((incident) => jsonEncode(incident.toJson())).toList());
    }

    Navigator.of(context).pop();
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
                      'Détails de l\'Incident',
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
                        Text('ID: ${widget.incident.id}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        Text('Description: ${widget.incident.description}', style: TextStyle(fontSize: 18)),
                        SizedBox(height: 10),
                        Text('Heure: ${widget.incident.time}', style: TextStyle(fontSize: 18)),
                        SizedBox(height: 20),
                        if (widget.incident.note != null && widget.incident.note!.isNotEmpty) ...[
                          Text('Note:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 5),
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(widget.incident.note!, style: TextStyle(fontSize: 16)),
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

