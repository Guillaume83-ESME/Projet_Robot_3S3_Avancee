import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/incident.dart';
import '../models/command.dart';
import '../models/robot_action.dart';
import '../widgets/battery_icon.dart';
import 'incident_list_page.dart';
import 'command_list_page.dart';
import 'actions_list_page.dart';
import 'bluetooth_connection_page.dart';
import 'settings_page.dart';
import 'battery_status_page.dart';

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

  @override
  void initState() {
    super.initState();
    loadCommands();
    loadActions();
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

  void _createTestAction(String actionType) async {
    String time = DateFormat('HH:mm:ss').format(DateTime.now());
    RobotAction newAction = RobotAction(id: actions.length + 1, description: actionType, time: time);
    Command newCommand = Command(id: commands.length + 1, action: actionType, time: time);

    setState(() {
      actions.insert(0, newAction);
      commands.insert(0, newCommand);
    });

    await saveActions();
    await saveCommands();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$actionType créé !')),
    );
  }

  void _resetActions() {
    setState(() {
      actions.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Actions réinitialisées !')));
  }

  void _resetIncidents() {
    setState(() {
      incidents.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Incidents réinitialisés !')));
  }

  void _resetCommands() {
    setState(() {
      commands.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Commandes réinitialisées !')));
  }


  void _connectBluetooth() {
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
    super.dispose();
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
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
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
                  onTap: () => _createTestAction("Arrêt du robot"),
                ),
                _buildActionCard(
                  title: 'Search Object',
                  icon: Icons.search,
                  color: Colors.orange,
                  onTap: () => _createTestAction("Chercher un objet"),
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
                ),
                _buildActionCard(
                  title: 'Bluetooth',
                  icon: Icons.bluetooth,
                  color: Colors.indigo,
                  onTap: _connectBluetooth,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return ScaleTransition(
      scale: _animation,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [color.withOpacity(0.3), color.withOpacity(0.5)]
                    : [color.withOpacity(0.7), color],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
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
                  Icon(icon, size: 48, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
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

