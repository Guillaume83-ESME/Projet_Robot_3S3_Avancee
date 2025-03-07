import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:app_settings/app_settings.dart';
import 'bluetooth_manager.dart';
import 'package:provider/provider.dart';
import 'bluetooth_state_manager.dart';
import 'bluetooth_command_page.dart';

class BluetoothConnectionPage extends StatefulWidget {
  @override
  _BluetoothConnectionPageState createState() => _BluetoothConnectionPageState();
}

class _BluetoothConnectionPageState extends State<BluetoothConnectionPage> with WidgetsBindingObserver {
  List<ScanResult> devicesList = [];
  List<BluetoothDevice> savedDevices = [];
  List<BluetoothDevice> connectedDevices = [];
  List<BluetoothDevice> selectedDevices = [];
  bool isScanning = false;
  String searchQuery = '';
  bool sortAscending = true;
  bool hideUnnamedDevices = false;
  bool sortByProximity = false;
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopScan();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsAndProceed();
    }
  }

  Future<void> _initializeApp() async {
    try {
      final bluetoothManager = Provider.of<BluetoothStateManager>(context, listen: false);
      await bluetoothManager.initializeBluetooth();
      bool firstLaunch = await isFirstLaunch();
      if (firstLaunch) {
        await showPermissionDialog(context);
      } else {
        await _checkPermissionsAndProceed();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'initialisation: $e')),
      );
    }
  }

  Future<void> _checkPermissionsAndProceed() async {
    bool permissionsGranted = await checkPermissions();
    if (permissionsGranted) {
      await _loadSavedDevices();
      await _getConnectedDevices();
      setState(() => _permissionsChecked = true);
    } else {
      await showPermissionDialog(context);
    }
  }

  Future<void> _loadSavedDevices() async {
    savedDevices = await FlutterBluePlus.bondedDevices;
    setState(() {});
  }

  Future<void> _getConnectedDevices() async {
    connectedDevices = await FlutterBluePlus.connectedSystemDevices;
    setState(() {});
  }

  void startContinuousScan() async {
    final bluetoothManager = Provider.of<BluetoothStateManager>(context, listen: false);
    try {
      setState(() => isScanning = true);
      await bluetoothManager.scanDevices();
      setState(() {
        devicesList = bluetoothManager.scanResults;
        isScanning = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du scan : $e')),
      );
      setState(() => isScanning = false);
    }
  }

  void stopScan() async {
    await FlutterBluePlus.stopScan();
    setState(() => isScanning = false);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      final bluetoothManager = Provider.of<BluetoothStateManager>(context, listen: false);
      await bluetoothManager.connectToDevice(device);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connecté à ${device.name}')),
      );
      await _getConnectedDevices();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion: $e')),
      );
    }
  }

  Future<void> _disconnectFromDevice() async {
    try {
      final bluetoothManager = Provider.of<BluetoothStateManager>(context, listen: false);
      await bluetoothManager.disconnectDevice();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Déconnecté')),
      );
      await _getConnectedDevices();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la déconnexion: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothManager = Provider.of<BluetoothStateManager>(context);

    if (!_permissionsChecked) {
      return _buildPermissionCheckingScreen();
    }

    List<ScanResult> filteredDevices = _getFilteredAndSortedDevices(bluetoothManager.scanResults);

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
              _buildConnectionStatus(bluetoothManager),
              _buildSearchAndFilter(),
              Expanded(child: _buildDevicesList(filteredDevices)),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildScanButton(),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Connexion HM10',
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
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.text_fields, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BluetoothCommandPage()),
                  );
                },
                tooltip: 'Commandes Bluetooth',
              ),
              IconButton(
                icon: Icon(Icons.help_outline, color: Colors.white),
                onPressed: () => _showHelpDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(BluetoothStateManager bluetoothManager) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bluetoothManager.isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              bluetoothManager.isConnected
                  ? 'Connecté à ${bluetoothManager.connectedDevice?.name ?? "Appareil inconnu"}'
                  : 'Non connecté',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (bluetoothManager.isConnected)
            ElevatedButton(
              onPressed: _disconnectFromDevice,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Déconnecter'),
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
            onChanged: (value) => setState(() => searchQuery = value),
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
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFilterButton(
                text: sortAscending ? 'Tri A-Z' : 'Tri Z-A',
                onPressed: () => setState(() {
                  sortAscending = !sortAscending;
                  sortByProximity = false;
                }),
              ),
              _buildFilterButton(
                text: sortByProximity ? 'Tri par proximité' : 'Tri par nom',
                onPressed: () => setState(() => sortByProximity = !sortByProximity),
              ),
              _buildFilterButton(
                text: hideUnnamedDevices ? 'Afficher tous' : 'Masquer sans nom',
                onPressed: () => setState(() => hideUnnamedDevices = !hideUnnamedDevices),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({required String text, required VoidCallback onPressed}) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(color: Colors.white70),
      ),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildDevicesList(List<ScanResult> devices) {
    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              isScanning ? 'Recherche en cours...' : 'Aucun appareil trouvé',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Appuyez sur le bouton de scan pour rechercher des appareils',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index].device;
        final rssi = devices[index].rssi;

        bool isPotentialHM10 = device.name.toLowerCase().contains('hm-10') ||
            device.name.toLowerCase().contains('hm10') ||
            device.name.toLowerCase().contains('ble') ||
            device.name.toLowerCase().contains('jdy');

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isPotentialHM10
              ? Colors.green.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          child: ListTile(
            leading: Icon(
              Icons.bluetooth,
              color: isPotentialHM10 ? Colors.green : Colors.blue,
            ),
            title: Text(
              device.name.isNotEmpty ? device.name : 'Appareil inconnu',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.remoteId.toString(),
                  style: TextStyle(color: Colors.white70),
                ),
                if (isPotentialHM10)
                  Text(
                    'Potentiellement un HM10',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$rssi dBm',
                  style: TextStyle(color: Colors.white70),
                ),
                Icon(
                  rssi > -60 ? Icons.signal_cellular_4_bar :
                  rssi > -70 ? Icons.network_cell :
                  rssi > -80 ? Icons.signal_cellular_alt :
                  Icons.signal_cellular_0_bar,
                  size: 16,
                  color: rssi > -70 ? Colors.green :
                  rssi > -80 ? Colors.orange : Colors.red,
                ),
              ],
            ),
            onTap: () => _connectToDevice(device),
          ),
        );
      },
    );
  }

  Widget _buildScanButton() {
    return FloatingActionButton.extended(
      onPressed: isScanning ? stopScan : startContinuousScan,
      icon: Icon(isScanning ? Icons.stop : Icons.bluetooth_searching),
      label: Text(isScanning ? 'Arrêter' : 'Scanner'),
      tooltip: isScanning ? 'Arrêter le scan' : 'Démarrer le scan',
      backgroundColor: isScanning ? Colors.red : Colors.green,
    );
  }

  List<ScanResult> _getFilteredAndSortedDevices(List<ScanResult> scanResults) {
    List<ScanResult> filteredDevices = scanResults.where((result) {
      bool matchesSearch = result.device.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          result.device.remoteId.toString().toLowerCase().contains(searchQuery.toLowerCase());
      bool isNamed = result.device.name.isNotEmpty && result.device.name != 'Appareil inconnu';
      return matchesSearch && (isNamed || !hideUnnamedDevices);
    }).toList();

    if (sortByProximity) {
      filteredDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
    } else if (sortAscending) {
      filteredDevices.sort((a, b) => a.device.name.compareTo(b.device.name));
    } else {
      filteredDevices.sort((a, b) => b.device.name.compareTo(a.device.name));
    }

    return filteredDevices;
  }

  Widget _buildPermissionCheckingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Permissions nécessaires',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkPermissionsAndProceed,
                child: Text('Vérifier les permissions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF3949AB),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> isFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('first_launch') ?? true;
    if (isFirstLaunch) {
      await prefs.setBool('first_launch', false);
    }
    return isFirstLaunch;
  }

  Future<bool> checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> showPermissionDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Autorisations nécessaires'),
          content: Text('Cette application nécessite des autorisations pour fonctionner.'),
          actions: <Widget>[
            TextButton(
              child: Text('Quitter'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Accorder'),
              onPressed: () async {
                Navigator.of(context).pop();
                bool granted = await checkPermissions();
                if (!granted) {
                  await showOpenSettingsDialog(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> showOpenSettingsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permissions requises'),
          content: Text('Vous devez accorder les permissions pour utiliser cette fonctionnalité. Voulez-vous accéder aux paramètres de l\'application ?'),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Ouvrir les paramètres'),
              onPressed: () async {
                Navigator.of(context).pop();
                await AppSettings.openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showHelpDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Aide'),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Text('Cette page permet de se connecter à un appareil HM10 en Bluetooth.'),
                Text('Activez le Bluetooth et la localisation pour que la recherche fonctionne.'),
                Text('Les appareils HM10 sont mis en évidence en vert.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

