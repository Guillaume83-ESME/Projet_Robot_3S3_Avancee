import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:app_settings/app_settings.dart';

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
    bool firstLaunch = await isFirstLaunch();
    if (firstLaunch) {
      await showPermissionDialog(context);
    } else {
      await _checkPermissionsAndProceed();
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
    if (await FlutterBluePlus.isSupported == false) {
      return;
    }

    if (await FlutterBluePlus.isOn) {
      setState(() => isScanning = true);
      FlutterBluePlus.startScan();
      FlutterBluePlus.scanResults.listen((results) {
        setState(() => devicesList = results);
      }, onError: (error) {
        print("Erreur de scan : $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du scan : $error')),
        );
        setState(() => isScanning = false);
      });
    }
  }

  void stopScan() async {
    await FlutterBluePlus.stopScan();
    setState(() => isScanning = false);
  }

  List<BluetoothDevice> _getFilteredDevices() {
    return filterDevices(
      savedDevices: savedDevices,
      connectedDevices: connectedDevices,
      searchQuery: searchQuery,
      hideUnnamedDevices: hideUnnamedDevices,
    );
  }

  void _showSavedAndConnectedDevices() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            _loadSavedDevices();
            _getConnectedDevices().then((_) {
              setState(() {});
            });

            List<BluetoothDevice> filteredDevices = _getFilteredDevices();
            if (sortAscending) {
              filteredDevices.sort((a, b) => a.name.compareTo(b.name));
            } else {
              filteredDevices.sort((a, b) => b.name.compareTo(a.name));
            }

            return AlertDialog(
              title: Text('Appareils enregistrés et connectés'),
              content: Container(
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: filteredDevices.length,
                  itemBuilder: (context, index) {
                    BluetoothDevice device = filteredDevices[index];
                    bool isConnected = connectedDevices.contains(device);
                    bool isSaved = savedDevices.contains(device);

                    return ListTile(
                      title: Text(device.name.isNotEmpty ? device.name : 'Appareil inconnu'),
                      subtitle: Text(isConnected ? 'Connecté' : (isSaved ? 'Enregistré' : '')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSaved)
                            IconButton(
                              icon: Icon(Icons.link_off),
                              onPressed: () => _unpairDevice(device),
                            ),
                          if (!isSaved)
                            IconButton(
                              icon: Icon(Icons.link),
                              onPressed: () => _pairDevice(device),
                            ),
                          IconButton(
                            icon: Icon(isConnected ? Icons.bluetooth_connected : Icons.bluetooth),
                            onPressed: () => _connectToDevice(device),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Fermer'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeSelectedDevices() async {
    for (var device in selectedDevices) {
      if (await device.isConnected) {
        await device.disconnect();
      }
      await device.removeBond();
    }
    await _loadSavedDevices();
    await _getConnectedDevices();
    setState(() => selectedDevices.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Appareils sélectionnés supprimés et déconnectés avec succès')),
    );
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      if (await device.isConnected) {
        await device.disconnect();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Déconnecté de ${device.name ?? 'Appareil inconnu'}')),
        );
      } else {
        await device.connect();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connecté à ${device.name ?? 'Appareil inconnu'}')),
        );
      }
      await _getConnectedDevices();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion : $e')),
      );
    }
  }

  void _toggleDeviceSelection(BluetoothDevice device) {
    setState(() {
      if (selectedDevices.contains(device)) {
        selectedDevices.remove(device);
      } else {
        selectedDevices.add(device);
      }
    });
  }

  Future<void> _showConnectionDialog(BluetoothDevice device) async {
    bool isConnected = await device.isConnected;
    if (isConnected) {
      await _disconnectFromDevice(device);
    } else {
      await _connectToDevice(device);
    }
  }

  Future<void> _disconnectFromDevice(BluetoothDevice device) async {
    bool? confirmDisconnect = await showDisconnectDialog(context, device);
    if (confirmDisconnect == true) {
      await device.disconnect();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Déconnecté de ${device.name ?? 'Appareil inconnu'}')),
      );
    }
    await _getConnectedDevices();
    setState(() {});
  }

  Future<void> _unpairDevice(BluetoothDevice device) async {
    try {
      await device.removeBond();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${device.name ?? 'Appareil inconnu'} dissocié avec succès')),
      );
      await _loadSavedDevices();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la dissociation : $e')),
      );
    }
  }

  Future<void> _pairDevice(BluetoothDevice device) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Veuillez appairer ${device.name ?? 'Appareil inconnu'} dans les paramètres Bluetooth.')),
    );
    await AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
  }


  @override
  Widget build(BuildContext context) {
    if (!_permissionsChecked) {
      return _buildPermissionCheckingScreen();
    }

    List<ScanResult> filteredDevices = _getFilteredAndSortedDevices();

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
              _buildSearchAndFilter(),
              Expanded(child: _buildDevicesList(filteredDevices)),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildScanButton(),
    );
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Appareils Bluetooth',
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
          IconButton(
            icon: Icon(Icons.devices, color: Colors.white),
            onPressed: _showSavedAndConnectedDevices,
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
              labelStyle: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.indigo[200],
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.indigo[200]!,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.indigo,
                ),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.indigo[200],
              ),
            ),
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
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
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white70
              : Colors.indigo[200],
        ),
      ),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildDevicesList(List<ScanResult> devices) {
    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index].device;
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.white.withOpacity(0.9),
          child: ListTile(
            title: Text(
              device.name.isNotEmpty ? device.name : 'Appareil inconnu',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            subtitle: Text(
              device.remoteId.toString(),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
            trailing: Text(
              '${devices[index].rssi} dBm',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
            onTap: () => _connectToDevice(device),
            onLongPress: () => _toggleDeviceSelection(device),
          ),
        );
      },
    );
  }

  Widget _buildScanButton() {
    return FloatingActionButton(
      onPressed: isScanning ? stopScan : startContinuousScan,
      child: Icon(isScanning ? Icons.stop : Icons.search),
      tooltip: isScanning ? 'Arrêter le scan' : 'Démarrer le scan',
      backgroundColor: isScanning ? Colors.red : Colors.green,
    );
  }

  List<ScanResult> _getFilteredAndSortedDevices() {
    List<ScanResult> filteredDevices = devicesList.where((result) {
      bool matchesSearch = result.device.name.toLowerCase().contains(searchQuery.toLowerCase());
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

  List<BluetoothDevice> filterDevices({
    required List<BluetoothDevice> savedDevices,
    required List<BluetoothDevice> connectedDevices,
    required String searchQuery,
    required bool hideUnnamedDevices,
  }) {
    List<BluetoothDevice> allDevices = [...savedDevices, ...connectedDevices];
    allDevices = allDevices.toSet().toList();
    return allDevices.where((device) {
      bool matchesSearch = device.name.toLowerCase().contains(searchQuery.toLowerCase());
      bool isNamed = device.name.isNotEmpty && device.name != 'Appareil inconnu';
      return matchesSearch && (isNamed || !hideUnnamedDevices || savedDevices.contains(device));
    }).toList();
  }

  List<ScanResult> filterAndSortDevices({
    required List<ScanResult> devicesList,
    required String searchQuery,
    required bool hideUnnamedDevices,
    required bool sortByProximity,
    required bool sortAscending,
  }) {
    List<ScanResult> filteredDevices = devicesList.where((result) {
      bool matchesSearch = result.device.name.toLowerCase().contains(searchQuery.toLowerCase());
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

  Future<bool?> showDisconnectDialog(BuildContext context, BluetoothDevice device) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Déconnexion'),
          content: Text('Voulez-vous vous déconnecter de ${device.name ?? 'Appareil inconnu'} ?'),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Déconnecter'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> showPairDialog(BuildContext context, BluetoothDevice device) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Appairer l\'appareil'),
          content: Text('Voulez-vous appairer ${device.name ?? 'Appareil inconnu'} ?'),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Appairer'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }
}

