import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'theme/theme_model.dart'; // Assurez-vous que le chemin est correct

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeModel(),
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
