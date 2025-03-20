import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:day35/pages/SignupLogin.dart';
import 'package:day35/pages/preferences.dart';
import 'package:day35/pages/home.dart';
import 'package:day35/pages/ApplianceSelection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(HomeEaseAIApp());
}

class HomeEaseAIApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
      routes: {
        '/loginSignup': (context) => LoginSignupScreen(),
        '/applianceSelection': (context) => ApplianceSelectionScreen(selectedAppliances: []), // Fixed issue
        '/preferences': (context) => PreferenceTagScreen(selectedAppliances: []),
        '/home': (context) => HomePage(),
      },
    );
  }
}

// Splash screen to check user authentication status
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
      nextScreen = HomePage();
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