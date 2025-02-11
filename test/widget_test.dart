import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mon Application',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: TextTheme(
          bodyLarge: TextStyle(fontSize: 18, color: Colors.black),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    Timer.periodic(Duration(milliseconds: 150), (timer) {
      setState(() {
        _progress += 0.01;
      });

      if (_progress >= 1.0) {
        timer.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/logo_projet.png',
            height: 200,
          ),
          SizedBox(height: 20),
          Text(
            'Chargement en cours...',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            '${(_progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          LinearProgressIndicator(value: _progress),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Command> commands = [];
  final List<Incident> incidents = [];
  final List<Action> actions = [];
  final List<SshConnection> sshHistory = [];
  int batteryPercentage = 100; // État de la batterie

  void _createTestAction(String actionType) {
    String time = DateFormat('HH:mm:ss').format(DateTime.now());
    Action newAction = Action(id: actions.length + 1, description: actionType, time: time);
    actions.insert(0, newAction);
    Command newCommand = Command(id: commands.length + 1, action: actionType, time: time);
    commands.insert(0, newCommand);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$actionType créé !')),
    );
  }

  void _createTestIncident() {
    String time = DateFormat('HH:mm:ss').format(DateTime.now());
    incidents.insert(0, Incident(id: incidents.length + 1, description: "Incident fictif", time: time));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Incident fictif créé !')),
    );
  }

  void _connectSSH() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SshConnectionPage(
          onConnect: (hostname, username) {
            setState(() {
              sshHistory.add(SshConnection(hostname: hostname, username: username));
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Connexion SSH établie avec $hostname')),
            );
          },
          history: sshHistory,
        ),
      ),
    );
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo_projet.png',
              height: 40,
            ),
            SizedBox(width: 10),
            Text('Page Principale'),
          ],
        ),
        actions: [
          IconButton(
            icon: BatteryIcon(percentage: batteryPercentage),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                _createTestAction("Arrêt du robot");
              },
              icon: Icon(Icons.stop),
              label: Text('Arrêt du robot'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _createTestAction("Chercher un objet");
              },
              icon: Icon(Icons.search),
              label: Text('Chercher un objet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IncidentListPage(incidents: incidents),
                  ),
                );
              },
              icon: Icon(Icons.warning),
              label: Text('Liste des incidents'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommandListPage(commands: commands),
                  ),
                );
              },
              icon: Icon(Icons.list),
              label: Text('Liste des commandes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ActionsListPage(actions: actions),
                  ),
                );
              },
              icon: Icon(Icons.list),
              label: Text('Liste des Actions du Robot'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BatteryStatusPage(),
                  ),
                );
              },
              icon: Icon(Icons.battery_full),
              label: Text('État de la batterie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _createTestIncident,
              icon: Icon(Icons.add_alert),
              label: Text('Créer un incident fictif'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _connectSSH,
              icon: Icon(Icons.vpn_lock),
              label: Text('Connexion SSH'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _connectBluetooth,
              icon: Icon(Icons.bluetooth),
              label: Text('Connexion Bluetooth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 16),
            Spacer(),
            /*ElevatedButton.icon(
              onPressed: () {
                SystemNavigator.pop();
              },
              icon: Icon(Icons.exit_to_app),
              label: Text('Quitter l\'application'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                minimumSize: Size(double.infinity, 50),
              ),
            ),*/
          ],
        ),
      ),
    );
  }
}

class Incident {
  final int id;
  final String description;
  final String time;

  Incident({required this.id, required this.description, required this.time});
}

class Command {
  final int id;
  final String action;
  final String time;

  Command({required this.id, required this.action, required this.time});
}

class Action {
  final int id;
  final String description;
  final String time;

  Action({required this.id, required this.description, required this.time});
}

class SshConnection {
  final String hostname;
  final String username;

  SshConnection({required this.hostname, required this.username});
}

class SshConnectionPage extends StatefulWidget {
  final Function(String, String) onConnect;
  final List<SshConnection> history;

  SshConnectionPage({required this.onConnect, required this.history});

  @override
  _SshConnectionPageState createState() => _SshConnectionPageState();
}

class _SshConnectionPageState extends State<SshConnectionPage> {
  final TextEditingController hostnameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void _connect() {
    String hostname = hostnameController.text;
    String username = usernameController.text;

    if (hostname.isNotEmpty && username.isNotEmpty) {
      widget.onConnect(hostname, username);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Connexion SSH"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: hostnameController,
              decoration: InputDecoration(labelText: "Adresse IP ou Nom d'hôte"),
            ),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(labelText: "Nom d'utilisateur"),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: "Mot de passe"),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _connect,
              child: Text("Se connecter"),
            ),
            SizedBox(height: 20),
            Text("Historique des connexions :"),
            Expanded(
              child: ListView.builder(
                itemCount: widget.history.length,
                itemBuilder: (context, index) {
                  final connection = widget.history[index];
                  return ListTile(
                    title: Text(connection.hostname),
                    subtitle: Text(connection.username),
                    onTap: () {
                      hostnameController.text = connection.hostname;
                      usernameController.text = connection.username;
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BluetoothConnectionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connexion Bluetooth'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Logique pour la connexion Bluetooth (à implémenter)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Connexion Bluetooth établie !')),
            );
          },
          child: Text('Se connecter via Bluetooth'),
        ),
      ),
    );
  }
}

class BatteryIcon extends StatelessWidget {
  final int percentage;

  BatteryIcon({required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.battery_full, color: Colors.grey[400]),
        Positioned(
          child: Text(
            '$percentage%',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class IncidentDetailPage extends StatelessWidget {
  final Incident incident;

  IncidentDetailPage({required this.incident});

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
            Text('ID: ${incident.id}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Description: ${incident.description}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Heure: ${incident.time}', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class CommandDetailPage extends StatelessWidget {
  final Command command;

  CommandDetailPage({required this.command});

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
            Text('ID: ${command.id}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Action: ${command.action}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Heure: ${command.time}', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class ActionDetailPage extends StatelessWidget {
  final Action action;

  ActionDetailPage({required this.action});

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
            Text('ID: ${action.id}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Description: ${action.description}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Heure: ${action.time}', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

// IncidentListPage
class IncidentListPage extends StatefulWidget {
  final List<Incident> incidents;

  IncidentListPage({required this.incidents});

  @override
  _IncidentListPageState createState() => _IncidentListPageState();
}

class _IncidentListPageState extends State<IncidentListPage> {
  List<Incident> filteredIncidents = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredIncidents = widget.incidents;
    searchController.addListener(() {
      filterIncidents();
    });
  }

  void filterIncidents() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredIncidents = widget.incidents.where((incident) {
        return incident.description.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Liste des Incidents')),
      body: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(labelText: 'Recherche...'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredIncidents.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('ID: ${filteredIncidents[index].id} - ${filteredIncidents[index].description}'),
                  subtitle: Text(filteredIncidents[index].time),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IncidentDetailPage(incident: filteredIncidents[index]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// CommandListPage
class CommandListPage extends StatefulWidget {
  final List<Command> commands;

  CommandListPage({required this.commands});

  @override
  _CommandListPageState createState() => _CommandListPageState();
}

class _CommandListPageState extends State<CommandListPage> {
  List<Command> filteredCommands = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredCommands = widget.commands;
    searchController.addListener(() {
      filterCommands();
    });
  }

  void filterCommands() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredCommands = widget.commands.where((command) {
        return command.action.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Liste des Commandes')),
      body: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(labelText: 'Recherche...'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredCommands.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('ID: ${filteredCommands[index].id} - ${filteredCommands[index].action}'),
                  subtitle: Text(filteredCommands[index].time),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommandDetailPage(command: filteredCommands[index]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// ActionsListPage
class ActionsListPage extends StatefulWidget {
  final List<Action> actions;

  ActionsListPage({required this.actions});

  @override
  _ActionsListPageState createState() => _ActionsListPageState();
}

class _ActionsListPageState extends State<ActionsListPage> {
  List<Action> filteredActions = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredActions = widget.actions;
    searchController.addListener(() {
      filterActions();
    });
  }

  void filterActions() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredActions = widget.actions.where((action) {
        return action.description.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Liste des Actions')),
      body: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(labelText: 'Recherche...'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredActions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('ID: ${filteredActions[index].id} - ${filteredActions[index].description}'),
                  subtitle: Text(filteredActions[index].time),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActionDetailPage(action: filteredActions[index]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BatteryStatusPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('État de la batterie'),
      ),
      body: Center(
        child: Text(
          'État de la batterie : 100%',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
