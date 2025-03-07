import 'package:flutter/foundation.dart';
import 'bluetooth_manager.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothStateManager extends ChangeNotifier {
  final BluetoothManager _bluetoothManager = BluetoothManager();
  bool _isConnected = false;
  BluetoothDevice? _connectedDevice;

  bool get isConnected => _isConnected;
  BluetoothDevice? get connectedDevice => _connectedDevice;

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

  List<ScanResult> get scanResults => _bluetoothManager.scanResults;

  Future<void> scanDevices() async {
    await _bluetoothManager.scanDevices();
    notifyListeners();
  }

  void dispose() {
    _bluetoothManager.dispose();
    super.dispose();
  }
}
