import 'package:flutter/material.dart';

class BatteryStatusPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('État de la batterie'),
      ),
      body: Center(
        child: Text('Page de l\'état de la batterie'),
      ),
    );
  }
}
