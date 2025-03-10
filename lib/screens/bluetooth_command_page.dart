import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bluetooth_state_manager.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/incident.dart';
import '../models/command.dart';
import '../models/robot_action.dart';

class BluetoothCommandPage extends StatefulWidget {
  @override
  _BluetoothCommandPageState createState() => _BluetoothCommandPageState();
}

class _BluetoothCommandPageState extends State<BluetoothCommandPage> with AutomaticKeepAliveClientMixin {
  final TextEditingController _commandController = TextEditingController();
  String _lastResponse = '';
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _responseSubscription;
  bool _isLoading = false;
  bool _isSubscribed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _setupResponseListener();
    });
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getStringList('bluetooth_messages') ?? [];
      setState(() {
        _messages = messagesJson
            .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
            .toList();
      });
    } catch (e) {
      print('Erreur lors du chargement des messages: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = _messages
          .map((message) => jsonEncode(message))
          .toList();
      await prefs.setStringList('bluetooth_messages', messagesJson);
    } catch (e) {
      print('Erreur lors de la sauvegarde des messages: $e');
    }
  }

  void _setupResponseListener() {
    // Vérifier si déjà abonné pour éviter les abonnements multiples
    if (_isSubscribed) return;

    final bluetoothManager = Provider.of<BluetoothStateManager>(context, listen: false);

    // Annuler l'abonnement existant s'il y en a un
    _responseSubscription?.cancel();

    _responseSubscription = bluetoothManager.responseStream.listen((response) {
      print('Réponse reçue: $response');
      setState(() {
        _lastResponse = response;
        _addMessage(response, false);
      });
    });

    _isSubscribed = true;
    print('Abonnement aux réponses configuré');
  }

  void _addMessage(String text, bool isFromUser) {
    setState(() {
      _messages.add({
        'text': text,
        'isFromUser': isFromUser,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    });
    _saveMessages();
  }

  @override
  void dispose() {
    print('Dispose appelé - annulation de l\'abonnement');
    _responseSubscription?.cancel();
    _commandController.dispose();
    _isSubscribed = false;
    super.dispose();
  }

  @override
  void deactivate() {
    print('Deactivate appelé - annulation de l\'abonnement');
    _responseSubscription?.cancel();
    _isSubscribed = false;
    super.deactivate();
  }

  Future<int> _getIncidentCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? incidentsJson = prefs.getStringList('incidents');
      if (incidentsJson != null) {
        return incidentsJson.length;
      }
    } catch (e) {
      print('Erreur lors de la récupération des incidents: $e');
    }
    return 0;
  }

  Future<int> _getCommandCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? commandsJson = prefs.getStringList('commands');
      if (commandsJson != null && commandsJson.isNotEmpty) {
        return commandsJson.length;
      }
    } catch (e) {
      print('Erreur lors de la récupération des commandes: $e');
    }
    return 0;
  }

  Future<int> _getActionCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? actionsJson = prefs.getStringList('actions');
      if (actionsJson != null && actionsJson.isNotEmpty) {
        return actionsJson.length;
      }
    } catch (e) {
      print('Erreur lors de la récupération des actions: $e');
    }
    return 0;
  }

  Future<void> _sendCommand() async {
    final bluetoothManager = Provider.of<BluetoothStateManager>(context, listen: false);
    if (!bluetoothManager.isConnected) {
      setState(() {
        _addMessage('Erreur : Non connecté au Bluetooth', false);
      });
      return;
    }

    if (_commandController.text.isEmpty) {
      setState(() {
        _addMessage('Erreur : Commande vide', false);
      });
      return;
    }

    String commandToSend = _commandController.text.trim();
    _addMessage(commandToSend, true);

    // Commandes spéciales
    String commandLower = commandToSend.toLowerCase();

    if (commandLower == 'incident') {
      int incidentCount = await _getIncidentCount();
      _addMessage('Il y a actuellement $incidentCount incident(s) enregistré(s).', false);
      _commandController.clear();
      return;
    }

    if (commandLower == 'commande' || commandLower == 'commandes') {
      int commandCount = await _getCommandCount();
      _addMessage('Vous avez effectué $commandCount commande(s).', false);
      _commandController.clear();
      return;
    }

    if (commandLower == 'action' || commandLower == 'actions') {
      int actionCount = await _getActionCount();
      _addMessage('Le robot a effectué $actionCount action(s).', false);
      _commandController.clear();
      return;
    }

    try {
      await bluetoothManager.sendBluetoothData(commandToSend);
      _commandController.clear();
    } catch (e) {
      _addMessage('Erreur d\'envoi : $e', false);
    }
  }

  void _clearMessages() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Effacer les messages'),
        content: Text('Voulez-vous vraiment effacer tous les messages ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _messages.clear();
              });
              _saveMessages();
              Navigator.of(context).pop();
            },
            child: Text('Effacer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bluetoothManager = Provider.of<BluetoothStateManager>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [Colors.grey[900]!, Colors.grey[800]!]
                : [Color(0xFF1A237E), Color(0xFF3949AB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              _buildConnectionStatus(bluetoothManager, isDarkMode),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: Colors.white))
                    : _buildMessagesList(isDarkMode),
              ),
              _buildCommandInput(isDarkMode, bluetoothManager),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Commande Bluetooth',
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
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _clearMessages,
            tooltip: 'Effacer les messages',
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(BluetoothStateManager bluetoothManager, bool isDarkMode) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bluetoothManager.isConnected
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            bluetoothManager.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: Colors.white,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              bluetoothManager.isConnected
                  ? 'Connecté à : ${bluetoothManager.connectedDevice?.name ?? "Appareil inconnu"}'
                  : 'Non connecté',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(bool isDarkMode) {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'Aucun message',
          style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _messages.length,
      reverse: true,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        final isFromUser = message['isFromUser'] as bool;
        final text = message['text'] as String;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisAlignment: isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isFromUser)
                CircleAvatar(
                  backgroundColor: Colors.green,
                  radius: 16,
                  child: Icon(Icons.android, size: 18, color: Colors.white),
                ),
              if (!isFromUser) SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isFromUser
                        ? Colors.blue.withOpacity(0.7)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFromUser ? 'Vous :' : 'Robot RMRO :',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        text,
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              if (isFromUser) SizedBox(width: 8),
              if (isFromUser)
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  radius: 16,
                  child: Icon(Icons.person, size: 18, color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommandInput(bool isDarkMode, BluetoothStateManager bluetoothManager) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commandController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Entrez votre commande...',
                hintStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendCommand(),
            ),
          ),
          SizedBox(width: 8),
          FloatingActionButton(
            onPressed: bluetoothManager.isConnected ? _sendCommand : null,
            backgroundColor: bluetoothManager.isConnected
                ? Colors.green
                : Colors.grey,
            mini: true,
            child: Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

