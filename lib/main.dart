import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/share_result_screen.dart';
import 'screens/social_feed_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/profile_screen.dart';



void main() {
  runApp(const DogBreedApp());
}

class DogBreedApp extends StatelessWidget {
  const DogBreedApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dog_chuchuu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue,
      textTheme: GoogleFonts.interTextTheme()),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/share': (context) => const ShareResultScreen(),
        '/feed': (context) => const SocialFeedScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
