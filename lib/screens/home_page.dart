import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bluetooth_state_manager.dart';
import 'package:intl/intl.dart';
import '../models/robot_action.dart';
import '../models/command.dart';
import '../models/incident.dart';
import 'actions_list_page.dart';
import 'command_list_page.dart';
import 'incident_list_page.dart';
import 'bluetooth_connection_page.dart';
import 'settings_page.dart';
import 'battery_status_page.dart';
import '../widgets/battery_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'bluetooth_command_page.dart'; // Importer pour utiliser addSharedBluetoothMessage
import 'dart:async';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final List<Command> commands = [];
  final List<Incident> incidents = [];
  final List<RobotAction> actions = [];
  final BatteryIcon batteryIcon = BatteryIcon(percentage: 100);
  late AnimationController _animationController;
  late Animation<double> _animation;
  StreamSubscription? _responseSubscription;
  String _lastResponse = '';
  bool _showResponseDialog = false;

  @override
  void initState() {
    super.initState();
    loadCommands();
    loadActions();
    loadIncidents();
    _initBluetooth();
    _setupResponseListener();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  Future<void> _initBluetooth() async {
    final bluetoothManager = Provider.of<BluetoothStateManager>(context, listen: false);
    await bluetoothManager.initializeBluetooth();
  }

  void _setupResponseListener() {
    final bluetoothManager = Provider.of<BluetoothStateManager>(context, listen: false);

    // Cancel existing subscription to avoid duplicate listeners
    _responseSubscription?.cancel();

    _responseSubscription = bluetoothManager.responseStream.listen((response) async {
      print('HomePage: response received: $response');

      // Ajouter la réponse du robot à l'historique des messages partagés
      await addSharedBluetoothMessage(response, false);

      setState(() {
        _lastResponse = response;

        // Check if it's a response to a stop or search command
        String responseLower = response.toLowerCase();
        if (responseLower.contains("arret") ||
            responseLower.contains("stop") ||
            responseLower.contains("recherche") ||
            responseLower.contains("search")) {

          _showResponseDialog = true;

          // Show the response dialog
          _showRobotResponseDialog(response);

          // Process the response according to its type
          if (responseLower.contains("incident")) {
            _addIncidentFromResponse(response);
          }
        }
      });
    }, onError: (error) {
      print('Error in response stream: $error');
    });
  }

  void _showRobotResponseDialog(String response) {
    // Only show dialog if we're mounted and app is active
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.smart_toy, color: Colors.blue),
                SizedBox(width: 10),
                Text('Réponse du Robot'),
              ],
            ),
            content: Text(response),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _showResponseDialog = false;
                  });
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _addIncidentFromResponse(String response) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing incidents
      List<String>? incidentsJson = prefs.getStringList('incidents') ?? [];
      List<Incident> incidents = incidentsJson
          .map((json) => Incident.fromJson(jsonDecode(json)))
          .toList();

      // Create new ID
      int newId = 1;
      if (incidents.isNotEmpty) {
        newId = incidents.map((i) => i.id).reduce((a, b) => a > b ? a : b) + 1;
      }

      // Create new incident
      String time = DateFormat('HH:mm:ss').format(DateTime.now());
      Incident newIncident = Incident(
          id: newId,
          description: response,
          time: time
      );

      // Add incident to list
      incidents.add(newIncident);

      // Save updated list
      List<String> updatedIncidentsJson = incidents
          .map((incident) => jsonEncode(incident.toJson()))
          .toList();

      await prefs.setStringList('incidents', updatedIncidentsJson);

      // Update local list
      setState(() {
        this.incidents.clear();
        this.incidents.addAll(incidents);
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nouvel incident détecté et ajouté'),
            backgroundColor: Colors.red,
          )
      );
    } catch (e) {
      print('Error adding incident from response: $e');
    }
  }

  Future<void> loadActions() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? actionsJson = prefs.getStringList('actions');
    if (actionsJson != null) {
      setState(() {
        actions.clear();
        actions.addAll(actionsJson.map((json) => RobotAction.fromJson(jsonDecode(json))).toList());
      });
    }
  }

  Future<void> loadCommands() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? commandsJson = prefs.getStringList('commands');
    if (commandsJson != null) {
      setState(() {
        commands.clear();
        commands.addAll(commandsJson.map((json) => Command.fromJson(jsonDecode(json))).toList());
      });
    }
  }

  Future<void> loadIncidents() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? incidentsJson = prefs.getStringList('incidents');
    if (incidentsJson != null) {
      setState(() {
        incidents.clear();
        incidents.addAll(incidentsJson.map((json) => Incident.fromJson(jsonDecode(json))).toList());
      });
    }
  }

  Future<void> saveActions() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> actionsJson = actions.map((action) => jsonEncode(action.toJson())).toList();
    await prefs.setStringList('actions', actionsJson);
  }

  Future<void> saveCommands() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> commandsJson = commands.map((command) => jsonEncode(command.toJson())).toList();
    await prefs.setStringList('commands', commandsJson);
  }

  Future<void> saveIncidents() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> incidentsJson = incidents.map((incident) => jsonEncode(incident.toJson())).toList();
    await prefs.setStringList('incidents', incidentsJson);
  }

  void _createTestAction(String actionType) async {
    String time = DateFormat('HH:mm:ss').format(DateTime.now());
    String commandToSend;
    String displayAction;

    switch (actionType) {
      case "STOP":
        commandToSend = "stop\r\n";
        displayAction = "Stop Robot";
        break;
      case "SEARCH":
        commandToSend = "search\r\n";
        displayAction = "Search Object";
        break;
      default:
        commandToSend = actionType.toLowerCase() + "\r\n";
        displayAction = actionType;
    }

    RobotAction newAction = RobotAction(id: actions.length + 1, description: displayAction, time: time);
    Command newCommand = Command(id: commands.length + 1, action: displayAction, time: time);

    setState(() {
      actions.insert(0, newAction);
      commands.insert(0, newCommand);
    });

    await saveActions();
    await saveCommands();

    final bluetoothManager = Provider.of<BluetoothStateManager>(context, listen: false);
    if (bluetoothManager.isConnected) {
      try {
        // Show a loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                SizedBox(width: 10),
                Text('Envoi de la commande "$displayAction"...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );

        // Ajouter la commande à l'historique des messages Bluetooth partagés
        await addSharedBluetoothMessage(commandToSend.trim(), true);

        // Send the command to the robot
        await bluetoothManager.sendBluetoothData(commandToSend);

        // Response will be handled by the responseStream listener
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'envoi Bluetooth: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Non connecté en Bluetooth. Action enregistrée localement.')),
      );
    }
  }

  void _resetActions() async {
    setState(() {
      actions.clear();
    });
    await saveActions();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Actions réinitialisées !')));
  }

  void _resetIncidents() async {
    setState(() {
      incidents.clear();
    });
    await saveIncidents();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Incidents réinitialisés !')));
  }

  void _resetCommands() async {
    setState(() {
      commands.clear();
    });
    await saveCommands();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Commandes réinitialisées !')));
  }

  void _connectBluetooth() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BluetoothConnectionPage(),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _responseSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothManager = Provider.of<BluetoothStateManager>(context);

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
              if (bluetoothManager.isConnected) _buildBluetoothStatus(),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBluetoothStatus() {
    final bluetoothManager = Provider.of<BluetoothStateManager>(context);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth_connected, color: Colors.green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Connecté à ${bluetoothManager.connectedDevice?.name ?? "Appareil"}',
              style: TextStyle(color: Colors.white),
            ),
          ),
          // Add an indicator to show the last response
          if (_lastResponse.isNotEmpty && !_showResponseDialog)
            GestureDetector(
              onTap: () {
                _showRobotResponseDialog(_lastResponse);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.message, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Voir message', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Hero(
                tag: 'logo',
                child: Image.asset(
                  'assets/images/logo_projet.png.jpg',
                  height: 40,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'R.MRO',
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
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: batteryIcon,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BatteryStatusPage()),
                  );
                },
              ),
              SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.settings, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsPage(
                        onResetActions: _resetActions,
                        onResetIncidents: _resetIncidents,
                        onResetCommands: _resetCommands
                    )),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final bluetoothManager = Provider.of<BluetoothStateManager>(context);
    bool isConnected = bluetoothManager.isConnected;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeTransition(
            opacity: _animation,
            child: Text(
              'Robot Control Center',
              style: TextStyle(
                fontSize: 28,
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
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildActionCard(
                  title: 'Stop Robot',
                  icon: Icons.stop_circle,
                  color: Colors.red,
                  onTap: isConnected ? () => _createTestAction("STOP") : null,
                  isEnabled: isConnected,
                ),
                _buildActionCard(
                  title: 'Search Object',
                  icon: Icons.search,
                  color: Colors.orange,
                  onTap: isConnected ? () => _createTestAction("SEARCH") : null,
                  isEnabled: isConnected,
                ),
                _buildActionCard(
                  title: 'Action List',
                  icon: Icons.list_alt,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ActionsListPage(actions: actions)),
                    );
                  },
                ),
                _buildActionCard(
                  title: 'Command List',
                  icon: Icons.code,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CommandListPage(commands: commands)),
                    );
                  },
                ),
                _buildActionCard(
                  title: 'Incident List',
                  icon: Icons.warning_amber,
                  color: Colors.amber,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => IncidentListPage(incidents: incidents)),
                    );
                  },
                  isEnabled: true, // Toujours activé
                ),
                _buildActionCard(
                  title: isConnected ? 'Bluetooth Connected' : 'Connect Bluetooth',
                  icon: Icons.bluetooth,
                  color: Colors.indigo,
                  onTap: _connectBluetooth,
                ),
                _buildActionCard(
                  title: 'Commande Bluetooth',
                  icon: Icons.text_fields,
                  color: Colors.purple,
                  onTap: isConnected ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BluetoothCommandPage()),
                    );
                  } : null,
                  isEnabled: isConnected,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    return ScaleTransition(
      scale: _animation,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isEnabled
                    ? Theme.of(context).brightness == Brightness.dark
                    ? [color.withOpacity(0.3), color.withOpacity(0.5)]
                    : [color.withOpacity(0.7), color]
                    : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.5)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isEnabled ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 48, color: isEnabled ? Colors.white : Colors.grey[400]),
                  SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: isEnabled ? Colors.white : Colors.grey[400],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: [
                        Shadow(
                          blurRadius: 2.0,
                          color: Colors.black.withOpacity(0.3),
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}