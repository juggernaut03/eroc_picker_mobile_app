import 'package:flutter/material.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const PickerApp());
}

class PickerApp extends StatelessWidget {
  const PickerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Picker',
      theme: AppTheme.light,
      home: const Scaffold(body: Center(child: Text('Picker App'))),
    );
  }
}
