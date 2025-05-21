import 'package:flutter/material.dart';

class SmartShoppingPage extends StatelessWidget {
  const SmartShoppingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("home decor")),
      body: const Center(
        child: Text("Home Decor - Coming Soon...", style: TextStyle(fontSize: 18)),
      ),
    );
  }
}