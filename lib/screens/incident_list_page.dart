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

class _IncidentListPageState extends State<IncidentListPage> with SingleTickerProviderStateMixin {
  List<Incident> filteredIncidents = [];
  List<Incident> selectedIncidents = [];
  TextEditingController searchController = TextEditingController();
  String selectedFilter = 'ID croissant';
  bool isSelecting = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

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
      filteredIncidents.sort((a, b) {
        switch (filter) {
          case 'ID croissant':
            return a.id.compareTo(b.id);
          case 'ID décroissant':
            return b.id.compareTo(a.id);
          case 'Description A-Z':
            return a.description.compareTo(b.description);
          case 'Description Z-A':
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
            children: [
              _buildAppBar(),
              _buildSearchAndFilter(),
              Expanded(child: _buildIncidentsList()),
            ],
          ),
        ),
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
            'Liste des Incidents',
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
                    if (selectedIncidents.isNotEmpty) {
                      deleteSelectedIncidents();
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
            dropdownColor: Color(0xFF3949AB),
            style: TextStyle(color: Colors.white),
            icon: Icon(Icons.arrow_drop_down, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentsList() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ListView.builder(
          itemCount: filteredIncidents.length,
          itemBuilder: (context, index) {
            final incident = filteredIncidents[index];
            return FadeTransition(
              opacity: _animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    index / filteredIncidents.length,
                    (index + 1) / filteredIncidents.length,
                    curve: Curves.easeOut,
                  ),
                )),
                child: _buildIncidentCard(incident),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildIncidentCard(Incident incident) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _onIncidentTap(incident),
        onLongPress: () => _onIncidentLongPress(incident),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selectedIncidents.contains(incident)
                  ? [Colors.blue.withOpacity(0.7), Colors.blue]
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
              'ID: ${incident.id} - ${incident.description}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(incident.time),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => deleteIndividualIncident(incident),
            ),
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    String query = value.toLowerCase();
    setState(() {
      filteredIncidents = widget.incidents.where((incident) {
        return incident.id.toString().contains(query) ||
            incident.description.toLowerCase().contains(query);
      }).toList();
      applyFilter(selectedFilter);
    });
  }

  void _onIncidentTap(Incident incident) {
    if (!isSelecting) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncidentDetailPage(incident: incident),
        ),
      );
    } else {
      toggleSelection(incident);
    }
  }

  void _onIncidentLongPress(Incident incident) {
    if (!isSelecting) {
      startSelectionMode();
    }
    toggleSelection(incident);
  }
}

