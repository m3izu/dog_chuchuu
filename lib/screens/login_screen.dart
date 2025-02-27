import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLogin = true;
  String email = '';
  String password = '';
  String confirmPassword = ''; // for sign-up only
  String errorMessage = '';
  bool isLoading = false;

  Future<void> _submit() async {
    // Validate all fields
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    // Save the field values
    form.save();

    // Additional check for sign-up: confirm password match
    if (!isLogin && password != confirmPassword) {
      setState(() {
        errorMessage = "Passwords do not match";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final endpoint = isLogin ? '/login' : '/signup';
      final url = Uri.parse('$backendUrl$endpoint');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Login success or Sign Up success
        if (isLogin) {
          // If login, store JWT token
          String token = data['token'];
          await storage.write(key: 'jwt', value: token);
        }
        Navigator.pop(context); // go back or move to next screen
      } else {
        setState(() {
          errorMessage = data['message'] ?? 'Authentication error';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove the AppBar to mimic the mock’s top layout
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Dog image at the top
                Image.asset(
                  'assets/dog_face.png',
                  height: 120,
                ),

                const SizedBox(height: 20),

                // Toggle for Sign Up / Sign In
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // SIGN UP Button
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => isLogin = false),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isLogin
                                  ? Colors.grey.shade300
                                  : Colors.brown,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 10),
                            alignment: Alignment.center,
                            child: Text(
                              'SIGN UP',
                              style: TextStyle(
                                color: isLogin ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // SIGN IN Button
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => isLogin = true),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isLogin
                                  ? Colors.brown
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 10),
                            alignment: Alignment.center,
                            child: Text(
                              'SIGN IN',
                              style: TextStyle(
                                color: isLogin ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Email
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: "Email",
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        onSaved: (val) => email = val!.trim(),
                        validator: (val) {
                          if (val == null || !val.contains('@')) {
                            return "Enter a valid email";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Password
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: "Password",
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        obscureText: true,
                        onSaved: (val) => password = val!.trim(),
                        validator: (val) {
                          if (val == null || val.length < 6) {
                            return "Minimum 6 characters";
                          }
                          return null;
                        },
                      ),

                      // Confirm Password (only in Sign Up mode)
                      if (!isLogin) ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: "Confirm Password",
                            filled: true,
                            fillColor: Colors.grey.shade200,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          obscureText: true,
                          onSaved: (val) => confirmPassword = val!.trim(),
                          validator: (val) {
                            if (val == null || val.length < 6) {
                              return "Minimum 6 characters";
                            }
                            return null;
                          },
                        ),
                      ],

                      // Forgot Password (only in Sign In mode)
                      if (isLogin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              // TODO: Handle forgot password
                            },
                            child: const Text("Forgot Password?"),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Error Message
                      if (errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),

                      // Loading or Button
                      isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.brown,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _submit,
                                child: Text(
                                  isLogin ? "SIGN IN" : "SIGN UP",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
