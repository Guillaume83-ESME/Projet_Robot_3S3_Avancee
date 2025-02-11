/*
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:app_settings/app_settings.dart';

class BluetoothConnectionPageClassic extends StatefulWidget {
  @override
  _BluetoothConnectionPageClassicState createState() => _BluetoothConnectionPageClassicState();
}

class _BluetoothConnectionPageClassicState extends State<BluetoothConnectionPageClassic> with WidgetsBindingObserver {
  List<BluetoothDevice> devicesList = [];
  List<BluetoothDevice> savedDevices = [];
  List<BluetoothDevice> connectedDevices = [];
  List<BluetoothDevice> selectedDevices = [];
  bool isScanning = false;
  String searchQuery = '';
  bool sortAscending = true;
  bool hideUnnamedDevices = false;
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsAndProceed();
    }
  }

  Future<void> _initializeApp() async {
    bool firstLaunch = await _isFirstLaunch();
    if (firstLaunch) {
      await _showPermissionDialog();
    } else {
      await _checkPermissionsAndProceed();
    }
  }

  Future<bool> _isFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('first_launch') ?? true;
    if (isFirstLaunch) {
      await prefs.setBool('first_launch', false);
    }
    return isFirstLaunch;
  }

  Future<bool> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> _checkPermissionsAndProceed() async {
    bool permissionsGranted = await _checkPermissions();
    if (permissionsGranted) {
      await _loadSavedDevices();
      await _getConnectedDevices();
      setState(() => _permissionsChecked = true);
    } else {
      await _showPermissionDialog();
    }
  }

  Future<void> _showPermissionDialog() async {
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
              onPressed: () => SystemNavigator.pop(),
            ),
            TextButton(
              child: Text('Accorder'),
              onPressed: () async {
                Navigator.of(context).pop();
                bool granted = await _checkPermissions();
                if (!granted) {
                  await _showOpenSettingsDialog();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showOpenSettingsDialog() async {
    showDialog(
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

  void startScan() async {
    if (await FlutterBluetoothSerial.instance.isEnabled ?? false) {
      setState(() {
        isScanning = true;
      });

      List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();

      setState(() {
        devicesList = bondedDevices;
        isScanning = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez activer le Bluetooth')),
      );
    }
  }

  Future<void> _loadSavedDevices() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> savedDeviceIds = prefs.getStringList('saved_devices') ?? [];

    List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();

    setState(() {
      savedDevices = bondedDevices.where((device) => savedDeviceIds.contains(device.address)).toList();
    });
  }

  Future<void> _getConnectedDevices() async {
    // Implémentation à adapter pour le Bluetooth Classic
    setState(() {});
  }

  Future<void> _saveDevice(BluetoothDevice device) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> savedDeviceIds = prefs.getStringList('saved_devices') ?? [];
    if (!savedDeviceIds.contains(device.address)) {
      savedDeviceIds.add(device.address);
      await prefs.setStringList('saved_devices', savedDeviceIds);
      await _loadSavedDevices();
    }
  }

  Future<void> _removeSelectedDevices() async {
    for (var device in selectedDevices) {
      if (connectedDevices.contains(device)) {
        // Déconnexion à implémenter pour le Bluetooth Classic
      }
      // Suppression du bond à implémenter pour le Bluetooth Classic
    }
    await _loadSavedDevices();
    await _getConnectedDevices();
    setState(() {
      selectedDevices.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Appareils sélectionnés supprimés et déconnectés avec succès')),
    );
    await AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
  }

  void connectToDevice(BluetoothDevice device) async {
    bool isConnected = connectedDevices.contains(device);

    if (isConnected) {
      bool? confirmDisconnect = await showDialog<bool>(
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

      if (confirmDisconnect == true) {
        // Déconnexion à implémenter pour le Bluetooth Classic
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Déconnecté de ${device.name ?? 'Appareil inconnu'}')),
        );
        await _getConnectedDevices();
        setState(() {});
      }
    } else {
      bool? confirmPair = await showDialog<bool>(
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

      if (confirmPair == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez appairer ${device.name ?? 'Appareil inconnu'} dans les paramètres Bluetooth.')),
        );
        await AppSettings.openAppSettings();
        await _getConnectedDevices();
        setState(() {});
      }
    }
  }

  List<BluetoothDevice> _getFilteredDevices() {
    List<BluetoothDevice> allDevices = [...savedDevices, ...connectedDevices];
    allDevices = allDevices.toSet().toList();
    return allDevices.where((device) {
      bool matchesSearch = device.name?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false;
      bool isNamed = device.name?.isNotEmpty ?? false && device.name != 'Appareil inconnu';
      return matchesSearch && (isNamed || !hideUnnamedDevices || savedDevices.contains(device));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Connexion Bluetooth Classic')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: startScan,
            child: Text('Démarrer le scan'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _getFilteredDevices().length,
              itemBuilder: (context, index) {
                BluetoothDevice device = _getFilteredDevices()[index];
                return ListTile(
                  title: Text(device.name ?? "Appareil inconnu"),
                  subtitle: Text(device.address),
                  trailing: ElevatedButton(
                    child: Text(connectedDevices.contains(device) ? 'Déconnecter' : 'Connecter'),
                    onPressed: () => connectToDevice(device),
                  ),
                  onTap: () => _saveDevice(device),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
*/