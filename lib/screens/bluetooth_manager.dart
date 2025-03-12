import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothManager {
  // Singleton instance
  static final BluetoothManager _instance = BluetoothManager._internal();

  factory BluetoothManager() {
    return _instance;
  }

  BluetoothManager._internal() {
    // Initialiser le StreamController comme broadcast pour permettre plusieurs écouteurs
    _responseController = StreamController<String>.broadcast();
  }

  // Variables
  BluetoothDevice? _connectedDevice;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notificationSubscription;

  // Stream controller pour les réponses Bluetooth
  late final StreamController<String> _responseController;
  Stream<String> get responseStream => _responseController.stream;

  // Constants for UUIDs - HM10 uses these standard UUIDs
  final String SERVICE_UUID = "ffe0";
  final String CHARACTERISTIC_UUID = "ffe1";

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<ScanResult> get scanResults => _scanResults;
  bool get isScanning => _isScanning;

  // Initialize Bluetooth
  Future<void> initializeBluetooth() async {
    FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);

    if (!await FlutterBluePlus.isSupported) {
      throw Exception('Bluetooth non supporté sur cet appareil');
    }

    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      if (state == BluetoothAdapterState.off) {
        print('Bluetooth est désactivé');
      }
    });
  }

  // Scan devices
  Future<void> scanDevices() async {
    if (_isScanning) return;
    _isScanning = true;
    _scanResults.clear();

    // Abonnement à onScanResults pour filtrer les résultats
    final subscription = FlutterBluePlus.onScanResults.listen((results) {
      _scanResults = results.where((r) {
        final name = r.device.platformName;
        // Filtrage pour HM10 ou tout appareil Bluetooth
        return true; // On accepte tous les appareils pour les voir
      }).toList();
    });

    try {
      // Démarrer le scan avec un timeout prolongé
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [], // On ne filtre pas par service pour voir tous les appareils
      );
      // Pause complémentaire pour s'assurer de la bonne réception des résultats
      await Future.delayed(const Duration(seconds: 1));
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Erreur lors du scan Bluetooth: $e');
    } finally {
      _isScanning = false;
      await subscription.cancel();
    }
  }

  // Connect to device
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      // Annuler les abonnements existants
      await _connectionSubscription?.cancel();
      await _notificationSubscription?.cancel();

      _connectionSubscription =
          device.connectionState.listen((BluetoothConnectionState state) {
            if (state == BluetoothConnectionState.disconnected) {
              _connectedDevice = null;
            }
          });

      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      await device.discoverServices();

      // Configurer l'écoute des notifications après la connexion
      await _setupNotifications();
    } catch (e) {
      print('Erreur de connexion: $e');
    }
  }

  // Méthode pour décoder les données Bluetooth avec fallback
  String _decodeBluetoothData(List<int> data) {
    try {
      // Essayer d'abord avec UTF-8 avec tolérance pour les caractères mal formés
      return utf8.decode(data, allowMalformed: true);
    } catch (e) {
      try {
        // Si UTF-8 échoue, utiliser Latin1 (ISO-8859-1) qui accepte tous les octets
        return latin1.decode(data);
      } catch (e) {
        // Si tout échoue, retourner une représentation hexadécimale
        return "HEX: " + data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      }
    }
  }

  // Setup notifications for receiving data
  Future<void> _setupNotifications() async {
    if (_connectedDevice == null) return;

    try {
      // Annuler l'abonnement existant aux notifications
      await _notificationSubscription?.cancel();

      List<BluetoothService> services = await _connectedDevice!.discoverServices();

      for (var service in services) {
        if (service.uuid.toString().toLowerCase().contains(SERVICE_UUID.toLowerCase())) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase().contains(CHARACTERISTIC_UUID.toLowerCase())) {
              if (char.properties.notify) {
                // Désactiver les notifications existantes avant d'en activer de nouvelles
                if (await char.isNotifying) {
                  await char.setNotifyValue(false);
                  await Future.delayed(Duration(milliseconds: 300)); // Petit délai pour s'assurer que la désactivation est complète
                }

                // Activer les nouvelles notifications
                await char.setNotifyValue(true);

                // S'assurer qu'il n'y a qu'un seul écouteur actif
                _notificationSubscription = char.onValueReceived.listen((value) {
                  // Afficher les données brutes en hexadécimal pour le débogage
                  String hexData = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
                  print('BluetoothManager: Données reçues brutes (hex): $hexData');

                  // Utiliser la méthode robuste de décodage
                  String response = _decodeBluetoothData(value);
                  print('BluetoothManager: Données reçues décodées: $response');

                  // Envoyer la réponse décodée au stream
                  _responseController.add(response);
                });

                print('Notifications configurées pour ${char.uuid}');
              }
              break;
            }
          }
          break;
        }
      }
    } catch (e) {
      print('Erreur lors de la configuration des notifications: $e');
    }
  }

  // Send Bluetooth data
  Future<void> sendBluetoothData(String command) async {
    if (_connectedDevice == null) {
      throw Exception('Aucun appareil Bluetooth connecté.');
    }

    try {
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      if (services.isEmpty) {
        throw Exception('Aucun service trouvé');
      }

      BluetoothService? targetService;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase().contains(SERVICE_UUID.toLowerCase())) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        throw Exception('Service HM10 non trouvé');
      }

      BluetoothCharacteristic? targetChar;
      for (var char in targetService.characteristics) {
        if (char.uuid.toString().toLowerCase().contains(CHARACTERISTIC_UUID.toLowerCase())) {
          targetChar = char;
          break;
        }
      }

      if (targetChar == null) {
        throw Exception('Caractéristique HM10 non trouvée');
      }

      // Convertir la commande en bytes et découper en paquets
      List<int> data = utf8.encode(command);
      const int chunkSize = 20;
      for (var i = 0; i < data.length; i += chunkSize) {
        var end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
        var chunk = data.sublist(i, end);
        await targetChar.write(chunk, withoutResponse: false);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // S'assurer que les notifications sont activées
      if (targetChar.properties.notify && !(await targetChar.isNotifying)) {
        await targetChar.setNotifyValue(true);

        // Annuler l'abonnement existant avant d'en créer un nouveau
        await _notificationSubscription?.cancel();

        _notificationSubscription = targetChar.onValueReceived.listen((value) {
          // Afficher les données brutes en hexadécimal pour le débogage
          String hexData = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
          print('BluetoothManager: Données reçues brutes après envoi (hex): $hexData');

          // Utiliser la méthode robuste de décodage
          String response = _decodeBluetoothData(value);
          print('BluetoothManager: Données reçues décodées après envoi: $response');

          // Envoyer la réponse décodée au stream
          _responseController.add(response);
        });
      }
    } catch (e) {
      print('Erreur lors de l\'envoi de données: $e');
      throw Exception('Erreur lors de l\'envoi de données: $e');
    }
  }

  // Disconnect from device
  Future<void> disconnectDevice() async {
    try {
      await _connectionSubscription?.cancel();
      await _notificationSubscription?.cancel();
      await _connectedDevice?.disconnect();
      _connectedDevice = null;
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
    }
  }

  // Dispose
  void dispose() {
    _connectionSubscription?.cancel();
    _notificationSubscription?.cancel();
    _connectedDevice?.disconnect();
    _responseController.close();
  }
}

