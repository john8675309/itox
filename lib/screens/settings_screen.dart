import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  void nukeKeys() {
    print('Deleting keys and resetting Tox...');
    // Call function to clear keys and reset Tox
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: nukeKeys,
          child: const Text('Reset Tox & Delete Keys'),
        ),
      ),
    );
  }
}
