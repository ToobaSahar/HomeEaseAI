import 'package:day35/pages/add_expense.dart';
import 'package:day35/pages/recipe_input_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'pages/peak_hours.dart'; // 👈 Import your notification agent
import 'package:intl/intl.dart'; // 👈 Required for DateFormat (used inside peak_hours.dart)
import 'package:day35/pages/ai_calculator_screen.dart';
import 'package:day35/pages/energy_calculator_screen.dart';
import 'firebase_options.dart';
import 'package:day35/pages/SignupLogin.dart';
import 'package:day35/pages/preferences.dart';
import 'package:day35/pages/home.dart' as home; // Avoids name conflict
import 'package:day35/pages/ApplianceSelection.dart';
import 'package:day35/pages/Chat_screen.dart';

// Newly added imports
import 'package:day35/pages/HomeDecor.dart';
import 'package:day35/pages/MealPlanning.dart';
import 'package:day35/pages/budget_screen.dart';
import 'package:day35/pages/EnergyUsage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  await Hive.openBox('chatHistory');

  // 👇 Initialize and schedule peak hour notification
  /*await initializeNotifications();
  await  fetchAndSchedulePeakHour();
*/
  runApp(HomeEaseAIApp());
}


class HomeEaseAIApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
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
            return MaterialPageRoute(
                builder: (_) =>
                    ApplianceSelectionScreen(selectedAppliances: []));
          case '/preferences':
            return MaterialPageRoute(
                builder: (_) =>
                    PreferenceTagScreen(selectedAppliances: []));
          case '/home':
            return MaterialPageRoute(builder: (_) => home.HomePage());
          case '/smartShopping':
            return MaterialPageRoute(builder: (_) => SmartShoppingPage());
          case '/energyUsage':
            return MaterialPageRoute(builder: (_) => EnergyCalculatorScreen());

          case '/mealPlanning':
            return MaterialPageRoute(builder: (_) => RecipePromptScreen());
          case '/budgeting':
            return MaterialPageRoute(builder: (_) => BudgetScreen());

          default:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Center(
                    child: Text('No route defined for ${settings.name}')),
              ),
            );
        }
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool staySignedIn = prefs.getBool("staySignedIn") ?? false;
    User? user = FirebaseAuth.instance.currentUser;

    Widget nextScreen;

    if (user != null && staySignedIn) {
      nextScreen = home.HomePage();
    } else {
      nextScreen = LoginSignupScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
