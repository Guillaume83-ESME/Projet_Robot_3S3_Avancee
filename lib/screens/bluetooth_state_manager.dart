import 'package:flutter/foundation.dart';
import 'bluetooth_manager.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class BluetoothStateManager extends ChangeNotifier {
  final BluetoothManager _bluetoothManager = BluetoothManager();
  bool _isConnected = false;
  BluetoothDevice? _connectedDevice;

  // Pour stocker les réponses récentes
  final List<String> _responses = [];
  List<String> get responses => _responses;

  // Stream pour les réponses
  Stream<String> get responseStream => _bluetoothManager.responseStream;

  bool get isConnected => _isConnected;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<ScanResult> get scanResults => _bluetoothManager.scanResults;

  StreamSubscription? _responseSubscription;

  BluetoothStateManager() {
    _setupResponseListener();
  }

  void _setupResponseListener() {
    // Annuler l'abonnement existant s'il y en a un
    _responseSubscription?.cancel();

    _responseSubscription = _bluetoothManager.responseStream.listen((response) {
      print('BluetoothStateManager: réponse reçue: $response');
      _responses.add(response);
      if (_responses.length > 20) {
        _responses.removeAt(0); // Garder seulement les 20 dernières réponses
      }
      notifyListeners();
    });
  }

  Future<void> initializeBluetooth() async {
    await _bluetoothManager.initializeBluetooth();
    _updateConnectionState();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await _bluetoothManager.connectToDevice(device);
    _updateConnectionState();
  }

  Future<void> disconnectDevice() async {
    await _bluetoothManager.disconnectDevice();
    _updateConnectionState();
  }

  Future<void> sendBluetoothData(String data) async {
    await _bluetoothManager.sendBluetoothData(data);
  }

  void _updateConnectionState() {
    _isConnected = _bluetoothManager.connectedDevice != null;
    _connectedDevice = _bluetoothManager.connectedDevice;
    notifyListeners();
  }

  Future<void> scanDevices() async {
    await _bluetoothManager.scanDevices();
    notifyListeners();
  }

  void clearResponses() {
    _responses.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _responseSubscription?.cancel();
    _bluetoothManager.dispose();
    super.dispose();
  }
}

