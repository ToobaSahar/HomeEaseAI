import 'package:flutter/material.dart';

class EnergyUsePage extends StatelessWidget {
  const EnergyUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Energy Use")),
      body: const Center(
        child: Text("Energy Use - Coming Soon...", style: TextStyle(fontSize: 18)),
      ),
    );
  }
}