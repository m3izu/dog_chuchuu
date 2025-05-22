// lib/main.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/share_result_screen.dart';
import 'screens/social_feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/dog_encyclopedia_screen.dart';

late final List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras(); // Fetch camera list before app runs
  runApp(const DogBreedApp());
}

class DogBreedApp extends StatelessWidget {
  const DogBreedApp({Key? key}) : super(key: key);

  // Our “alternate” color (#967869) as a constant:
  static const Color altColor = Color(0xFF967869);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dog_chuchuu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 1) Use Inter as our global font:
        textTheme: GoogleFonts.interTextTheme(),

        // 2) Build a ColorScheme: primary remains Blue, secondary = #967869
        primaryColor: Colors.white,         // <-- use this instead
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.blue,       // you can keep a real swatch here
  ).copyWith(
    secondary: altColor,   
        ),

        // 3) AppBar default: backgroundColor = #967869, title/icons = white
        appBarTheme: const AppBarTheme(
          backgroundColor: altColor,
          foregroundColor: Colors.white,
        ),

        // 4) FAB default: backgroundColor = #967869, icon/text = white
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: altColor,
          foregroundColor: Colors.white,
        ),

        // 5) ElevatedButton default style: use backgroundColor (not primary)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: altColor,   // <— replaced primary: with backgroundColor:
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // 6) Default Icon color: when no explicit color is set, use #967869
        iconTheme: const IconThemeData(color: altColor),
      ),

      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => HomeScreen(cameras: cameras),
        '/login': (context) => const LoginScreen(),
        '/share': (context) => const ShareResultScreen(),
        '/feed': (context) => const SocialFeedScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/encyclopedia': (context) => const DogEncyclopediaScreen(),
      },
    );
  }
}
