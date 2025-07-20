import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class EnergyCalculatorScreen extends StatefulWidget {
  @override
  _EnergyCalculatorScreenState createState() => _EnergyCalculatorScreenState();
}

class _EnergyCalculatorScreenState extends State<EnergyCalculatorScreen> {
  List<Map<String, dynamic>> appliances = [];
  Map<String, TextEditingController> usageControllers = {};
  String energyTips = '';
  bool isLoading = false;
  bool isFetching = true;

  @override
  void initState() {
    super.initState();
    loadAppliances();
  }

  Future<void> loadAppliances() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      final docSnapshot =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!docSnapshot.exists) {
        throw Exception("User document not found");
      }

      final data = docSnapshot.data();
      final List<dynamic>? applianceData = data?['Appliances'];

      if (applianceData == null || applianceData.isEmpty) {
        throw Exception("No appliances found");
      }

      setState(() {
        appliances = applianceData.cast<Map<String, dynamic>>();
        for (var appliance in appliances) {
          final name = appliance['name'];
          usageControllers[name] = TextEditingController();
        }
        isFetching = false;
      });
    } catch (e) {
      setState(() {
        appliances = [];
        isFetching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  double calculateEnergyUnits(double wattage, double hours) {
    return (wattage * hours) / 1000; // kWh
  }

  String buildPrompt() {
    String prompt =
        "Suggest how to reduce electricity consumption based on the following data:\n";

    for (var appliance in appliances) {
      final name = appliance['name'];
      final wattage = appliance['wattage'];
      final usageText = usageControllers[name]?.text ?? '0';
      final hours = double.tryParse(usageText) ?? 0.0;
      final kWh = calculateEnergyUnits(wattage.toDouble(), hours).toStringAsFixed(2);

      prompt +=
      "- $name (Wattage: ${wattage}W, Usage: ${hours} hrs/day, Energy: $kWh kWh/day)\n";
    }

    prompt +=
    "\nGive practical, smart suggestions to reduce electricity consumption using this data.";
    return prompt;
  }

  Future<void> generateTips() async {
    setState(() {
      isLoading = true;
      energyTips = '';
    });

    final prompt = buildPrompt();
    final response = await http.post(
      Uri.parse('https://api.together.xyz/inference'),
      headers: {
        'Authorization':
        'Bearer tgp_v1_4g2MHcOfbm6Yeh-ix_DZtoUyrVCM5UOxCgG25WI5mB4',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "meta-llama/Llama-4-Scout-17B-16E-Instruct",
        "prompt": prompt,
        "max_tokens": 500,
        "temperature": 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        energyTips = data['output'];
        isLoading = false;
      });
    } else {
      setState(() {
        energyTips = "Failed to get suggestions.";
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    usageControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Energy Consumption AI Agent")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isFetching
            ? Center(child: CircularProgressIndicator())
            : appliances.isEmpty
            ? Center(child: Text("No appliances found."))
            : ListView(
          children: [
            Text("Enter usage time (hrs/day):",
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            ...appliances.map((appliance) {
              final name = appliance['name'];
              final wattage = appliance['wattage'];

              return Card(
                child: ListTile(
                  title: Text("$name (${wattage}W)"),
                  subtitle: TextField(
                    controller: usageControllers[name],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: "Usage Time (hrs/day)"),
                  ),
                ),
              );
            }).toList(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: generateTips,
              child: isLoading
                  ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text("Generate Smart Energy Report"),
            ),
            SizedBox(height: 20),
            if (energyTips.isNotEmpty) ...[
              Text("AI Energy Saving Suggestions:",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text(energyTips, style: TextStyle(fontSize: 14)),
            ]
          ],
        ),
      ),
    );
  }
}
