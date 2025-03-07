import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'theme/theme_model.dart'; // Assurez-vous que le chemin est correct
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'theme/theme_model.dart';
import 'screens/bluetooth_state_manager.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeModel()),
        ChangeNotifierProvider(create: (context) => BluetoothStateManager()),
      ],
      child: Consumer<ThemeModel>(
        builder: (context, themeModel, child) {
          return MaterialApp(
            title: 'Mon Application',
            theme: themeModel.isDarkMode ? ThemeData.dark() : ThemeData.light(),
            home: SplashScreen(),
          );
        },
      ),
    );
  }
}

