import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bluetooth_state_manager.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/incident.dart';
import '../models/command.dart';
import '../models/robot_action.dart';
import 'package:flutter/services.dart';

// Clé pour stocker les messages Bluetooth dans SharedPreferences
const String BLUETOOTH_MESSAGES_KEY = 'bluetooth_messages';

// Fonction utilitaire pour ajouter un message à l'historique partagé
Future<void> addSharedBluetoothMessage(String text, bool isFromUser) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    List<String> messagesJson = prefs.getStringList(BLUETOOTH_MESSAGES_KEY) ?? [];

    List<Map<String, dynamic>> messages = messagesJson
        .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
        .toList();

    // Si le message n'est pas de l'utilisateur (donc du robot) et qu'il y a des messages précédents
    if (!isFromUser && messages.isNotEmpty) {
      // Vérifier si le dernier message est aussi du robot et a été reçu dans les 2 dernières secondes
      final lastMessage = messages.isNotEmpty ? messages.last : null;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (lastMessage != null &&
          lastMessage['isFromUser'] == false &&
          (now - (lastMessage['timestamp'] as int) < 2000)) {
        // Concaténer avec le message précédent au lieu d'ajouter un nouveau
        lastMessage['text'] = lastMessage['text'] + text;
        lastMessage['timestamp'] = now; // Mettre à jour le timestamp

        // Mettre à jour la liste des messages
        List<String> updatedMessagesJson = messages
            .map((message) => jsonEncode(message))
            .toList();

        await prefs.setStringList(BLUETOOTH_MESSAGES_KEY, updatedMessagesJson);
        return; // Sortir de la fonction car le message a été fusionné
      }
    }

    // Si on arrive ici, c'est qu'on n'a pas fusionné le message, donc on l'ajoute normalement
    messages.add({
      'text': text,
      'isFromUser': isFromUser,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isExpanded': false // Pour la fonctionnalité "Lire la suite"
    });

    // Limiter à 100 messages pour éviter de surcharger SharedPreferences
    if (messages.length > 100) {
      messages = messages.sublist(messages.length - 100);
    }

    List<String> updatedMessagesJson = messages
        .map((message) => jsonEncode(message))
        .toList();

    await prefs.setStringList(BLUETOOTH_MESSAGES_KEY, updatedMessagesJson);
  } catch (e) {
    print('Erreur lors de l\'ajout du message partagé: $e');
  }
}

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

  // Buffer pour agréger les messages du robot
  String _messageBuffer = '';
  Timer? _bufferTimer;

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
      final messagesJson = prefs.getStringList(BLUETOOTH_MESSAGES_KEY) ?? [];
      setState(() {
        _messages = messagesJson
            .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
            .toList();

        // S'assurer que tous les messages ont la propriété isExpanded
        for (var message in _messages) {
          if (!message.containsKey('isExpanded')) {
            message['isExpanded'] = false;
          }
        }
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
      await prefs.setStringList(BLUETOOTH_MESSAGES_KEY, messagesJson);
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
      if (mounted) {  // Vérifier si le widget est toujours monté
        _processRobotResponse(response);
      }
    }, onError: (error) {
      print('Erreur dans le stream de réponses: $error');
    });

    _isSubscribed = true;
    print('Abonnement aux réponses configuré');
  }

  void _processRobotResponse(String response) {
    // Annuler le timer existant s'il y en a un
    _bufferTimer?.cancel();

    // Ajouter la réponse au buffer
    _messageBuffer += response;

    // Définir un nouveau timer pour traiter le buffer après un délai
    // Cela permet d'agréger plusieurs fragments reçus rapidement
    _bufferTimer = Timer(Duration(milliseconds: 500), () {
      if (_messageBuffer.isNotEmpty) {
        setState(() {
          _lastResponse = _messageBuffer;
          _addMessage(_messageBuffer, false);

          // Traiter le message agrégé
          String responseLower = _messageBuffer.toLowerCase();

          // Vérifier si c'est un incident
          if (responseLower.contains("incident detecte")) {
            _addIncidentFromMessage(_messageBuffer);
          }

          // Vérifier si c'est une action
          if (responseLower.contains("action effectuee") ||
              responseLower.contains("arret du robot") ||
              responseLower.contains("demarrage du robot") ||
              responseLower.contains("objet trouve")) {
            _addActionFromMessage(_messageBuffer);
            print('Action détectée: $_messageBuffer');
          }

          // Vérifier si c'est une commande
          if (responseLower.contains("demande")) {
            if (responseLower.contains("demarrage") ||
                responseLower.contains("arret")) {
              _addCommandFromMessage(_messageBuffer);
            }
          } else if (responseLower.contains("recherche objet")) {
            _addCommandFromMessage(_messageBuffer);
          }

          // Réinitialiser le buffer
          _messageBuffer = '';
        });
      }
    });
  }

  // Méthode pour ajouter un incident à partir d'un message
  Future<void> _addIncidentFromMessage(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Récupérer les incidents existants
      List<String>? incidentsJson = prefs.getStringList('incidents') ?? [];
      List<Incident> incidents = incidentsJson
          .map((json) => Incident.fromJson(jsonDecode(json)))
          .toList();

      // Créer un nouvel ID (le plus grand ID + 1)
      int newId = 1;
      if (incidents.isNotEmpty) {
        newId = incidents.map((i) => i.id).reduce((a, b) => a > b ? a : b) + 1;
      }

      // Créer un nouvel incident
      String time = DateFormat('HH:mm:ss').format(DateTime.now());
      Incident newIncident = Incident(
          id: newId,
          description: message,
          time: time
      );

      // Ajouter l'incident à la liste
      incidents.add(newIncident);

      // Sauvegarder la liste mise à jour
      List<String> updatedIncidentsJson = incidents
          .map((incident) => jsonEncode(incident.toJson()))
          .toList();

      await prefs.setStringList('incidents', updatedIncidentsJson);

      // Afficher un message de confirmation
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nouvel incident ajouté à la liste des incidents'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          )
      );

      print('Incident ajouté: $message');
    } catch (e) {
      print('Erreur lors de l\'ajout de l\'incident: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ajout de l\'incident: $e'),
            backgroundColor: Colors.red,
          )
      );
    }
  }

  // Méthode pour ajouter une action à partir d'un message
  Future<void> _addActionFromMessage(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Récupérer les actions existantes au format StringList (utilisé par HomePage)
      List<String>? actionsJsonList = prefs.getStringList('actions') ?? [];
      List<RobotAction> actions = actionsJsonList
          .map((json) => RobotAction.fromJson(jsonDecode(json)))
          .toList();

      print('Actions existantes récupérées: ${actions.length}');

      // Créer un nouvel ID (le plus grand ID + 1)
      int newId = 1;
      if (actions.isNotEmpty) {
        newId = actions.map((a) => a.id).reduce((a, b) => a > b ? a : b) + 1;
      }

      // Créer une nouvelle action
      String time = DateFormat('HH:mm:ss').format(DateTime.now());
      RobotAction newAction = RobotAction(
          id: newId,
          description: message,
          time: time
      );

      // Ajouter l'action à la liste
      actions.add(newAction);

      // Sauvegarder la liste mise à jour au format StringList
      List<String> updatedActionsJsonList = actions
          .map((action) => jsonEncode(action.toJson()))
          .toList();

      await prefs.setStringList('actions', updatedActionsJsonList);

      print('Action ajoutée avec succès: $message');
      print('Nombre total d\'actions: ${actions.length}');

      // Afficher un message de confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Nouvelle action ajoutée à la liste des actions'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 3),
            )
        );
      }
    } catch (e) {
      print('Erreur lors de l\'ajout de l\'action: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'ajout de l\'action: $e'),
              backgroundColor: Colors.red,
            )
        );
      }
    }
  }

  // Méthode pour ajouter une commande à partir d'un message
  Future<void> _addCommandFromMessage(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Récupérer les commandes existantes au format StringList (utilisé par HomePage)
      List<String>? commandsJsonList = prefs.getStringList('commands') ?? [];
      List<Command> commands = commandsJsonList
          .map((json) => Command.fromJson(jsonDecode(json)))
          .toList();

      print('Commandes existantes récupérées: ${commands.length}');

      // Créer un nouvel ID (le plus grand ID + 1)
      int newId = 1;
      if (commands.isNotEmpty) {
        newId = commands.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
      }

      // Créer une nouvelle commande
      String time = DateFormat('HH:mm:ss').format(DateTime.now());
      Command newCommand = Command(
          id: newId,
          action: message,
          time: time
      );

      // Ajouter la commande à la liste
      commands.add(newCommand);

      // Sauvegarder la liste mise à jour au format StringList
      List<String> updatedCommandsJsonList = commands
          .map((command) => jsonEncode(command.toJson()))
          .toList();

      await prefs.setStringList('commands', updatedCommandsJsonList);

      print('Commande ajoutée avec succès: $message');
      print('Nombre total de commandes: ${commands.length}');

      // Afficher un message de confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Nouvelle commande ajoutée à la liste des commandes'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            )
        );
      }
    } catch (e) {
      print('Erreur lors de l\'ajout de la commande: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'ajout de la commande: $e'),
              backgroundColor: Colors.red,
            )
        );
      }
    }
  }

  void _addMessage(String text, bool isFromUser) async {
    if (mounted) {  // Vérifier si le widget est toujours monté
      // Vérifier si on peut fusionner avec le dernier message
      bool merged = false;

      if (!isFromUser && _messages.isNotEmpty) {
        final lastMessage = _messages.last;
        final now = DateTime.now().millisecondsSinceEpoch;

        if (lastMessage['isFromUser'] == false &&
            (now - (lastMessage['timestamp'] as int) < 2000)) {
          // Fusionner avec le dernier message
          setState(() {
            lastMessage['text'] = lastMessage['text'] + text;
            lastMessage['timestamp'] = now;
          });
          merged = true;
        }
      }

      // Si pas fusionné, ajouter comme nouveau message
      if (!merged) {
        setState(() {
          _messages.add({
            'text': text,
            'isFromUser': isFromUser,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'isExpanded': false
          });
        });
      }

      await _saveMessages();
    }
  }

  @override
  void dispose() {
    print('Dispose appelé - annulation de l\'abonnement');
    _responseSubscription?.cancel();
    _bufferTimer?.cancel();
    _commandController.dispose();
    _isSubscribed = false;
    super.dispose();
  }

  @override
  void deactivate() {
    print('Deactivate appelé - annulation de l\'abonnement');
    _responseSubscription?.cancel();
    _bufferTimer?.cancel();
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
      List<String>? commandsJsonList = prefs.getStringList('commands');
      if (commandsJsonList != null) {
        return commandsJsonList.length;
      }
    } catch (e) {
      print('Erreur lors de la récupération des commandes: $e');
    }
    return 0;
  }

  Future<int> _getActionCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? actionsJsonList = prefs.getStringList('actions');
      if (actionsJsonList != null) {
        return actionsJsonList.length;
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

    String commandToSend = _commandController.text.trim() + '\r\n';
    _addMessage(commandToSend.trim(), true);

    // Commandes spéciales
    String commandLower = commandToSend.toLowerCase();

    if (commandLower == 'incidents\r\n') {
      int incidentCount = await _getIncidentCount();
      _addMessage('Il y a actuellement $incidentCount incident(s) enregistré(s).', false);
      _commandController.clear();
      return;
    }

    if (commandLower == 'commande\r\n' || commandLower == 'commandes\r\n') {
      int commandCount = await _getCommandCount();
      _addMessage('Vous avez effectué $commandCount commande(s).', false);
      _commandController.clear();
      return;
    }

    if (commandLower == 'action\r\n' || commandLower == 'actions\r\n') {
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
            onPressed: () async {
              setState(() {
                _messages.clear();
              });
              await _saveMessages();

              // Effacer également les messages partagés
              final prefs = await SharedPreferences.getInstance();
              await prefs.setStringList(BLUETOOTH_MESSAGES_KEY, []);

              Navigator.of(context).pop();
            },
            child: Text('Effacer'),
          ),
        ],
      ),
    );
  }

  // Méthode pour afficher le message complet dans une boîte de dialogue
  void _showFullMessageDialog(BuildContext context, String message, bool isFromUser) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isFromUser ? Icons.person : Icons.android,
                color: isFromUser ? Colors.blue : Colors.green,
              ),
              SizedBox(width: 10),
              Text(isFromUser ? 'Votre message' : 'Message du Robot'),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(message),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Fermer'),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Message copié dans le presse-papiers'),
                    duration: Duration(seconds: 2),
                  ),
                );
                Navigator.of(context).pop();
              },
              child: Text('Copier'),
            ),
          ],
        );
      },
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

        // Déterminer si le message est long (plus de 100 caractères)
        bool isLongMessage = text.length > 100;

        // Texte à afficher (tronqué ou complet selon l'état d'expansion)
        String displayText = isLongMessage && message['isExpanded'] == false
            ? text.substring(0, 100) + '...'
            : text;

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
                        displayText,
                        style: TextStyle(color: Colors.white),
                      ),
                      // Afficher le bouton "Lire la suite" si le message est long
                      if (isLongMessage)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              // Inverser l'état d'expansion
                              message['isExpanded'] = !message['isExpanded'];
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              message['isExpanded'] == true ? 'Voir moins' : 'Lire la suite',
                              style: TextStyle(
                                color: Colors.lightBlueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      // Alternative: bouton pour voir le message complet dans une boîte de dialogue
                      if (isLongMessage)
                        GestureDetector(
                          onTap: () {
                            _showFullMessageDialog(context, text, isFromUser);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Voir tout dans une fenêtre',
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
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