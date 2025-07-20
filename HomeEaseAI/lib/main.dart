import 'package:day35/pages/add_expense.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:day35/pages/energy_calculator_screen.dart';
import 'firebase_options.dart';
import 'package:day35/pages/SignupLogin.dart';
import 'package:day35/pages/preferences.dart';
import 'package:day35/pages/home.dart' as home; // Avoids name conflict
import 'package:day35/pages/ApplianceSelection.dart';
import 'package:day35/pages/Chat_screen.dart';
import 'package:day35/pages/energy_bill_analyzer_screen.dart';

// Newly added imports
import 'package:day35/pages/HomeDecor.dart';
import 'package:day35/pages/MealPlanning.dart';
import 'package:day35/pages/budget_screen.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> setupFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permissions on iOS
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Get the device token and save it to Firestore if needed
  String? token = await messaging.getToken();
  print("📲 FCM Token: $token");

  // OPTIONAL: Save this token to Firestore under the user's doc
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await Hive.openBox('chatHistory');

  await setupFirebaseMessaging();

  runApp(const HomeEaseAIApp());
}

class HomeEaseAIApp extends StatefulWidget {
  const HomeEaseAIApp({super.key});

  @override
  State<HomeEaseAIApp> createState() => _HomeEaseAIAppState();
}

class _HomeEaseAIAppState extends State<HomeEaseAIApp> {
  Widget? initialScreen;

  @override
  void initState() {
    super.initState();
    determineInitialScreen();

  }

  void determineInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final bool staySignedIn = prefs.getBool("staySignedIn") ?? false;
    final User? user = FirebaseAuth.instance.currentUser;

    Widget screen = (user != null && staySignedIn)
        ? home.HomePage()
        : LoginSignupScreen();

    setState(() {
      initialScreen = screen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: initialScreen ??
          const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatTitle: args['chatTitle'],
              chatId: args['chatId'],
              tabId: args['tabId'],
            ),
          );
        }

        switch (settings.name) {
          case '/loginSignup':
            return MaterialPageRoute(builder: (_) => LoginSignupScreen());
          case '/applianceSelection':
            return MaterialPageRoute(builder: (_) => ApplianceSelectionScreen(selectedAppliances: []));
          case '/preferences':
            return MaterialPageRoute(builder: (_) => PreferenceTagScreen(selectedAppliances: []));
          case '/home':
            return MaterialPageRoute(builder: (_) => home.HomePage());
          case '/energyUsage':
            return MaterialPageRoute(builder: (_) => EnergyCalculatorScreen());
          case '/energyBillAnalyzer':
            return MaterialPageRoute(builder: (_) => EnergyBillAnalyzerScreen());
          case '/mealPlanning':
            return MaterialPageRoute(builder: (_) => RecipePromptScreen());
          case '/budgeting':
            return MaterialPageRoute(builder: (_) => BudgetScreen());
          case '/homeDecor':
            return MaterialPageRoute(builder: (_) => HomeDecor());
          default:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Center(child: Text('No route defined for ${settings.name}')),
              ),
            );
        }
      },
    );
  }
}


