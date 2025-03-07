import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bluetooth_state_manager.dart';

class BluetoothCommandPage extends StatefulWidget {
  @override
  _BluetoothCommandPageState createState() => _BluetoothCommandPageState();
}

class _BluetoothCommandPageState extends State<BluetoothCommandPage> {
  final TextEditingController _commandController = TextEditingController();
  String _lastResponse = '';

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  Future<void> _sendCommand() async {
    final bluetoothManager = Provider.of<BluetoothStateManager>(context, listen: false);
    if (!bluetoothManager.isConnected) {
      setState(() {
        _lastResponse = 'Erreur : Non connecté au Bluetooth';
      });
      return;
    }

    if (_commandController.text.isEmpty) {
      setState(() {
        _lastResponse = 'Erreur : Commande vide';
      });
      return;
    }

    try {
      await bluetoothManager.sendBluetoothData(_commandController.text);
      setState(() {
        _lastResponse = 'Commande envoyée : ${_commandController.text}';
      });
      _commandController.clear();
    } catch (e) {
      setState(() {
        _lastResponse = 'Erreur d\'envoi : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildConnectionStatus(bluetoothManager, isDarkMode),
                      SizedBox(height: 20),
                      _buildCommandInput(isDarkMode),
                      SizedBox(height: 10),
                      _buildSendButton(bluetoothManager, isDarkMode),
                      SizedBox(height: 20),
                      _buildResponseSection(isDarkMode),
                    ],
                  ),
                ),
              ),
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
          Text(
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
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(BluetoothStateManager bluetoothManager, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(16),
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

  Widget _buildCommandInput(bool isDarkMode) {
    return TextField(
      controller: _commandController,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Entrez votre commande',
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildSendButton(BluetoothStateManager bluetoothManager, bool isDarkMode) {
    return ElevatedButton(
      onPressed: bluetoothManager.isConnected ? _sendCommand : null,
      child: Text('Envoyer la commande'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDarkMode ? Colors.blueGrey[700] : Colors.blue[700],
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildResponseSection(bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dernière réponse :',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _lastResponse,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

