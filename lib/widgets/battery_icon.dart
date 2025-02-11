import 'package:flutter/material.dart';

class BatteryIcon extends StatelessWidget {
  final int percentage;
  BatteryIcon({required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.battery_full, color: Colors.grey[400]),
        Positioned(
          child: Text(
            '$percentage%',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
