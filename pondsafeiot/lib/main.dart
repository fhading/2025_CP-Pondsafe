import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'main_navigation.dart';
import 'water_history.dart';
import 'rain_history.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PondSafeApp());
}

class PondSafeApp extends StatelessWidget {
  const PondSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "PondSafe IoT",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF2F6FF),
      ),

      
      routes: {
        '/water-history': (context) => const WaterHistoryPage(),
        '/rain-history': (context) => const RainHistoryPage(),
      },

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData) {
            return const MainNavigation();
          } else {
            return const LoginPage();
          }
        },
      ),
    );
  }
}
