import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart'; // Make sure storage is imported from here

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Check if the user is logged in by reading the JWT token
  Future<bool> _isLoggedIn() async {
    final token = await storage.read(key: 'jwt');
    return token != null;
  }

  @override
  void initState() {
    super.initState();
    // Wait for 3 seconds and then navigate based on token existence
    Timer(const Duration(seconds: 3), () async {
      if (await _isLoggedIn()) {
        Navigator.pushReplacementNamed(context, '/feed');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff988558),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/dog_face.png",
              height: 150,
              width: 200,
              fit: BoxFit.fitHeight,
            ),
            const SizedBox(height: 16),
            const Text(
              "OnlyDogs",
              textAlign: TextAlign.start,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "An AI dog breed identifier",
              textAlign: TextAlign.start,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
