import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/incident.dart';
import 'incident_detail_page.dart';

class IncidentListPage extends StatefulWidget {
  final List<Incident> incidents;

  IncidentListPage({required this.incidents});

  @override
  _IncidentListPageState createState() => _IncidentListPageState();
}

class _IncidentListPageState extends State<IncidentListPage> {
  List<Incident> filteredIncidents = [];
  List<Incident> selectedIncidents = [];
  TextEditingController searchController = TextEditingController();
  String selectedFilter = 'ID croissant';
  bool isSelecting = false;
  final List<String> filterOptions = [
    'ID croissant',
    'ID décroissant',
    'Description A-Z',
    'Description Z-A',
    'Date récente',
    'Date ancienne',
  ];

  @override
  void initState() {
    super.initState();
    loadIncidents();
  }

  Future<void> saveIncidents() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> incidentsJson = filteredIncidents.map((incident) => jsonEncode(incident.toJson())).toList();
    await prefs.setStringList('incidents', incidentsJson);
  }

  Future<void> loadIncidents() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? incidentsJson = prefs.getStringList('incidents');
    if (incidentsJson != null) {
      setState(() {
        filteredIncidents = incidentsJson
            .map((json) => Incident.fromJson(jsonDecode(json)))
            .toList();
        widget.incidents.clear();
        widget.incidents.addAll(filteredIncidents);
      });
      applyFilter(selectedFilter);
    }
  }

  void applyFilter(String filter) {
    setState(() {
      selectedFilter = filter;
      switch (filter) {
        case 'ID croissant':
          filteredIncidents.sort((a, b) => a.id.compareTo(b.id));
          break;
        case 'ID décroissant':
          filteredIncidents.sort((a, b) => b.id.compareTo(a.id));
          break;
        case 'Description A-Z':
          filteredIncidents.sort((a, b) => a.description.compareTo(b.description));
          break;
        case 'Description Z-A':
          filteredIncidents.sort((a, b) => b.description.compareTo(a.description));
          break;
        case 'Date récente':
          filteredIncidents.sort((a, b) => b.time.compareTo(a.time));
          break;
        case 'Date ancienne':
          filteredIncidents.sort((a, b) => a.time.compareTo(b.time));
          break;
      }
    });
    saveIncidents();
  }

  void resetIncidents() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Êtes-vous sûr de vouloir réinitialiser la liste des incidents ?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  filteredIncidents.clear();
                  widget.incidents.clear();
                });
                final prefs = SharedPreferences.getInstance();
                prefs.then((prefs) => prefs.remove('incidents'));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Liste des incidents réinitialisée !')));
                Navigator.of(context).pop();
              },
              child: Text('Réinitialiser'),
            ),
          ],
        );
      },
    );
  }

  void deleteIndividualIncident(Incident incident) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Êtes-vous sûr de vouloir supprimer cet incident ?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  filteredIncidents.remove(incident);
                  widget.incidents.remove(incident);
                });
                saveIncidents();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Incident supprimé : ${incident.description}')),
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

  void deleteSelectedIncidents() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Êtes-vous sûr de vouloir supprimer ces incidents ?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  filteredIncidents.removeWhere((incident) => selectedIncidents.contains(incident));
                  widget.incidents.removeWhere((incident) => selectedIncidents.contains(incident));
                  selectedIncidents.clear();
                });
                saveIncidents();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Incidents supprimés !')));
                Navigator.of(context).pop();
              },
              child: Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  void toggleSelection(Incident incident) {
    setState(() {
      if (selectedIncidents.contains(incident)) {
        selectedIncidents.remove(incident);
      } else {
        selectedIncidents.add(incident);
      }
    });
  }

  void startSelectionMode() {
    setState(() {
      isSelecting = true;
      selectedIncidents.clear();
    });
  }

  void endSelectionMode() {
    setState(() {
      isSelecting = false;
      selectedIncidents.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Liste des Incidents'),
        actions: [
          if (isSelecting)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                if (selectedIncidents.isNotEmpty) {
                  deleteSelectedIncidents();
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
                      filteredIncidents = widget.incidents.where((incident) {
                        return incident.id.toString().contains(query) ||
                            incident.description.toLowerCase().contains(query);
                      }).toList();
                      applyFilter(selectedFilter);
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
              itemCount: filteredIncidents.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onLongPress: () {
                    startSelectionMode();
                    toggleSelection(filteredIncidents[index]);
                  },
                  child: ListTile(
                    title: Text('ID: ${filteredIncidents[index].id} - ${filteredIncidents[index].description}'),
                    subtitle: Text(filteredIncidents[index].time),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => deleteIndividualIncident(filteredIncidents[index]),
                    ),

                    tileColor: selectedIncidents.contains(filteredIncidents[index]) ? Colors.blue[100] : null,
                    onTap: () {
                      if (!isSelecting) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IncidentDetailPage(incident: filteredIncidents[index]),
                          ),
                        );
                      } else {
                        toggleSelection(filteredIncidents[index]);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          String time = DateFormat('HH:mm:ss').format(DateTime.now());
          int newId = (widget.incidents.isNotEmpty ? widget.incidents.last.id : 0) + 1;
          Incident newIncident = Incident(id: newId, description: "Nouvel Incident", time: time);
          setState(() {
            widget.incidents.add(newIncident);
            filteredIncidents.add(newIncident);
            saveIncidents();
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nouvel incident ajouté !')));
        },
        child: Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        child: IconButton(
          icon: Icon(Icons.refresh),
          onPressed: resetIncidents,
        ),
      ),
    );
  }
}
