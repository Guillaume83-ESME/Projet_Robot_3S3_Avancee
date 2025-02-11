import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_model.dart'; // Assurez-vous que ce chemin est correct

class SettingsPage extends StatefulWidget {
  final Function onResetActions;
  final Function onResetIncidents;
  final Function onResetCommands;

  SettingsPage({
    required this.onResetActions,
    required this.onResetIncidents,
    required this.onResetCommands,
  });

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? selectedBluetoothVersion;

  @override
  void initState() {
    super.initState();
    _loadBluetoothPreference();
  }

  Future<void> _loadBluetoothPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedVersion = prefs.getString('bluetooth_version');

    // Vérifiez si la version sauvegardée est valide
    if (savedVersion == null || !['BLE and Bluetooth 5.2', 'Classic Bluetooth'].contains(savedVersion)) {
      savedVersion = 'BLE and Bluetooth 5.2'; // Valeur par défaut
    }

    setState(() {
      selectedBluetoothVersion = savedVersion;
    });
  }

  Future<void> _saveBluetoothPreference(String version) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('bluetooth_version', version);
  }

  @override
  Widget build(BuildContext context) {
    // Obtenez l'instance du modèle de thème ici
    final themeModel = Provider.of<ThemeModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Paramètres'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Options de personnalisation',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            SwitchListTile(
              title: Text('Mode Sombre'),
              value: themeModel.isDarkMode,
              onChanged: (bool value) {
                themeModel.toggleTheme();
              },
            ),
            SizedBox(height: 20),
            DropdownButton<String>(
              value: selectedBluetoothVersion,
              hint: Text('Choisissez la version Bluetooth'),
              items: <String>['BLE and Bluetooth 5.2', 'Classic Bluetooth']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedBluetoothVersion = newValue;
                  _saveBluetoothPreference(newValue!);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
