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
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
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

    // Retourne true si toutes les permissions sont accordées, sinon false
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
              onPressed: () => SystemNavigator.pop(), // Quitte l'application
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
              onPressed: () {
                Navigator.of(context).pop(); // Ferme le dialogue
              },
            ),
            TextButton(
              child: Text('Ouvrir les paramètres'),
              onPressed: () async {
                Navigator.of(context).pop(); // Ferme le dialogue
                await AppSettings.openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  // Démarre un scan continu pour détecter les appareils Bluetooth
  void startContinuousScan() async {
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth non supporté par cet appareil");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth non supporté par cet appareil')),
      );
      return;
    }

    if (await FlutterBluePlus.isOn) {
      setState(() {
        isScanning = true; // Met l'état du scan à true
      });

      try {
        // Démarre le scan sans timeout
        FlutterBluePlus.startScan(); // Enlève le timeout

        FlutterBluePlus.scanResults.listen((results) {
          print("Résultats du scan : ${results.length}");
          setState(() {
            devicesList = results; // Met à jour la liste des appareils
          });
        }, onError: (error) {
          print("Erreur de scan : $error");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors du scan : $error')),
          );
          setState(() {
            isScanning = false; // Arrête le scan en cas d'erreur
          });
        });
      } catch (e) {
        print("Erreur lors du démarrage du scan : $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du démarrage du scan : $e')),
        );
        setState(() {
          isScanning = false; // Arrête le scan en cas d'exception
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez activer le Bluetooth')),
      );
    }
  }

  void stopScan() async {
    await FlutterBluePlus.stopScan();
    setState(() {
      isScanning = false; // Met l'état à false lorsque le scan est arrêté
    });
  }


  // Charge les appareils enregistrés depuis SharedPreferences
  Future<void> _loadSavedDevices() async {
    List<BluetoothDevice> bondedDevices = await FlutterBluePlus.bondedDevices;
    setState(() {
      savedDevices = bondedDevices;
    });
  }





  // Récupère les appareils actuellement connectés
  Future<void> _getConnectedDevices() async {
    connectedDevices = await FlutterBluePlus.connectedSystemDevices;
    setState(() {});
  }

  // Enregistre un appareil dans SharedPreferences
  Future<void> _saveDevice(BluetoothDevice device) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> savedDeviceIds = prefs.getStringList('saved_devices') ?? [];
    if (!savedDeviceIds.contains(device.remoteId.toString())) {
      savedDeviceIds.add(device.remoteId.toString());
      await prefs.setStringList('saved_devices', savedDeviceIds);
      await _loadSavedDevices();
    }
  }

  Future<void> _removeSelectedDevices() async {
    for (var device in selectedDevices) {
      if (connectedDevices.contains(device)) {
        await device.disconnect();
      }
      await device.removeBond();
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

  void _connectToDevice(BluetoothDevice device) async {
    // Vérifie si l'appareil est déjà connecté
    bool isConnected = connectedDevices.contains(device);

    if (isConnected) {
      // Si l'appareil est déjà connecté, demander la déconnexion
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
        await device.disconnect();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Déconnecté de ${device.name ?? 'Appareil inconnu'}')),
        );
      }
    } else {
      // Si l'appareil n'est pas connecté, demander l'apairage
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
        // Rediriger vers les paramètres Bluetooth pour l'apairage
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez appairer ${device.name ?? 'Appareil inconnu'} dans les paramètres Bluetooth.')),
        );
        await AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
      }
    }

    // Met à jour la liste des appareils connectés après déconnexion ou connexion
    await _getConnectedDevices();
    setState(() {});
  }

  // Filtre les appareils affichés selon la recherche et d'autres critères
  List<BluetoothDevice> _getFilteredDevices() {
    List<BluetoothDevice> allDevices = [...savedDevices, ...connectedDevices];
    allDevices = allDevices.toSet().toList();
    return allDevices.where((device) {
      bool matchesSearch = device.name.toLowerCase().contains(searchQuery.toLowerCase());
      bool isNamed = device.name.isNotEmpty && device.name != 'Appareil inconnu';
      return matchesSearch && (isNamed || !hideUnnamedDevices || savedDevices.contains(device));
    }).toList();
  }

  void _showConnectionDialog(BluetoothDevice device) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Connexion'),
          content: Text('Voulez-vous vous connecter à ${device.name ?? 'Appareil inconnu'} ?'),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Connecter'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // Lancer la connexion à l'appareil
        await device.connect();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connecté à ${device.name ?? 'Appareil inconnu'}')),
        );
        // Mettre à jour la liste des appareils connectés après connexion
        await _getConnectedDevices();
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la connexion : $e')),
        );
      }
    }
  }



  void _showSavedAndConnectedDevices() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Charger les appareils connectés et sauvegardés
            _loadSavedDevices(); // Mettre à jour savedDevices
            _getConnectedDevices().then((_) {
              setState(() {}); // Met à jour l'interface après avoir obtenu les appareils connectés
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Rechercher',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              sortAscending = !sortAscending;
                            });
                          },
                          child: Text(sortAscending ? 'Tri A-Z' : 'Tri Z-A'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              hideUnnamedDevices = !hideUnnamedDevices;
                            });
                          },
                          child: Text(hideUnnamedDevices ? 'Afficher tous' : 'Masquer sans nom'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredDevices.length,
                        itemBuilder: (context, index) {
                          BluetoothDevice device = filteredDevices[index];
                          bool isConnected = connectedDevices.contains(device);
                          bool isSaved = savedDevices.contains(device);
                          int rssi = devicesList.firstWhere(
                                (result) => result.device.remoteId == device.remoteId,
                            orElse: () => ScanResult(
                              device: device,
                              rssi: -100,
                              timeStamp: DateTime.now(),
                              advertisementData: AdvertisementData(
                                advName: '',
                                txPowerLevel: null,
                                connectable: false,
                                manufacturerData: {},
                                serviceData: {},
                                serviceUuids: [],
                                appearance: null,
                              ),
                            ),
                          ).rssi;

                          return ListTile(
                            title: Text(device.name.isNotEmpty ? device.name : 'Appareil inconnu'),
                            subtitle: Text('${isConnected ? 'Connecté' : (isSaved ? 'Enregistré' : '')} - RSSI: $rssi dBm'),
                            onTap: () async {
                              // Afficher la boîte de dialogue de connexion
                              bool? confirmConnect = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Connexion'),
                                    content: Text('Voulez-vous vous connecter à ${device.name ?? 'Appareil inconnu'} ?'),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text('Annuler'),
                                        onPressed: () => Navigator.of(context).pop(false),
                                      ),
                                      TextButton(
                                        child: Text('Connecter'),
                                        onPressed: () => Navigator.of(context).pop(true),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirmConnect == true) {
                                try {
                                  await device.connect();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Connecté à ${device.name ?? 'Appareil inconnu'}')),
                                  );
                                  await _getConnectedDevices(); // Met à jour la liste des appareils connectés
                                  setState(() {});
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erreur lors de la connexion : $e')),
                                  );
                                }
                              }
                            },
                            onLongPress: () {
                              setState(() {
                                _toggleDeviceSelection(device);
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Fermer'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Supprimer sélectionnés'),
                  onPressed: selectedDevices.isNotEmpty ? () async {
                    await _removeSelectedDevices();
                    Navigator.of(context).pop();
                    _showSavedAndConnectedDevices(); // Rafraîchit la liste après suppression
                  } : null,
                ),
              ],
            );
          },
        );
      },
    );
  }


  // Ajoute ou enlève un appareil de la sélection
  void _toggleDeviceSelection(BluetoothDevice device) {
    setState(() {
      if (selectedDevices.contains(device)) {
        selectedDevices.remove(device);
      } else {
        selectedDevices.add(device);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopScan();  // Arrêter le scan lors de la destruction de la page
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    if (!_permissionsChecked) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Permissions nécessaires'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkPermissionsAndProceed,
                child: Text('Vérifier les permissions'),
              ),
            ],
          ),
        ),
      );
    }

    List<ScanResult> filteredDevices = devicesList.where((result) {
      bool matchesSearch = result.device.name.toLowerCase().contains(searchQuery.toLowerCase());
      bool isNamed = result.device.name.isNotEmpty && result.device.name != 'Appareil inconnu';
      return matchesSearch && (isNamed || !hideUnnamedDevices);
    }).toList();

    // Tri des appareils
    if (sortByProximity) {
      filteredDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
    } else if (sortAscending) {
      filteredDevices.sort((a, b) => a.device.name.compareTo(b.device.name));
    } else {
      filteredDevices.sort((a, b) => b.device.name.compareTo(a.device.name));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Appareils Bluetooth à proximité'),
        actions: [
          IconButton(
            icon: Icon(Icons.devices),
            onPressed: _showSavedAndConnectedDevices, // Ouvre la liste des appareils appairés
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value; // Met à jour la valeur de la recherche à chaque modification
                });
              },
              decoration: InputDecoration(
                labelText: 'Rechercher',
                prefixIcon: Icon(Icons.search), // Icône de recherche
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    sortAscending = !sortAscending;
                    sortByProximity = false;
                  });
                },
                child: Text(sortAscending ? 'Tri A-Z' : 'Tri Z-A'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    sortByProximity = !sortByProximity;
                  });
                },
                child: Text(sortByProximity ? 'Tri par proximité' : 'Tri par nom'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    hideUnnamedDevices = !hideUnnamedDevices;
                  });
                },
                child: Text(hideUnnamedDevices ? 'Afficher tous' : 'Masquer sans nom'),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredDevices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(filteredDevices[index].device.name.isNotEmpty
                      ? filteredDevices[index].device.name
                      : 'Appareil inconnu'),
                  subtitle: Text(filteredDevices[index].device.remoteId.toString()),
                  trailing: Text('${filteredDevices[index].rssi} dBm'),
                  onTap: () => _connectToDevice(filteredDevices[index].device), // Connexion à l'appareil
                  onLongPress: () {
                    _toggleDeviceSelection(filteredDevices[index].device); // Sélectionner/désélectionner
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isScanning ? stopScan : startContinuousScan,
        child: Icon(isScanning ? Icons.stop : Icons.search), // Change l'icône selon l'état
        tooltip: isScanning ? 'Arrêter le scan' : 'Démarrer le scan',
        backgroundColor: isScanning ? Colors.red : Colors.green, // Change la couleur selon l'état
      ),
    );
  }

}
