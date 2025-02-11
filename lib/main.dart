// main.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:tflite_flutter/tflite_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const DogBreedApp());
}

class DogBreedApp extends StatelessWidget {
  const DogBreedApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dog_chuchuu, a dog breed classifier',
      theme: ThemeData(primarySwatch: Colors.blue),
      // Define named routes for navigation.
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/share': (context) => const ShareResultScreen(),
        '/feed': (context) => const SocialFeedScreen(),
      },
    );
  }
}

//
// 1. HOME SCREEN – Dog Breed Analyzer
//
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Interpreter? _interpreter;
  List<String>? _labels;
  File? _image;
  Map<String, double>? _predictions;
  
  final int _inputSize = 224;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  // Load TFLite model & labels
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      _labels = await loadLabels('assets/labels.txt');
      debugPrint('Model & labels loaded.');
    } catch (e) {
      debugPrint('Error loading model: $e');
    }
  }

  // Load label names from text file
  Future<List<String>> loadLabels(String path) async {
    String data = await DefaultAssetBundle.of(context).loadString(path);
    return data.split('\n').map((e) => e.trim()).toList();
  }

  // Image preprocessing: Resize & Normalize
  Future<Float32List> preprocessImage(File imageFile) async {
    Uint8List imageBytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception("Failed to decode image");

    img.Image resizedImage = img.copyResize(image, width: _inputSize, height: _inputSize);
    var buffer = Float32List(_inputSize * _inputSize * 3);
    var pixelIndex = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        int pixel = resizedImage.getPixel(x, y);
        buffer[pixelIndex++] = img.getRed(pixel) / 255.0;
        buffer[pixelIndex++] = img.getGreen(pixel) / 255.0;
        buffer[pixelIndex++] = img.getBlue(pixel) / 255.0;
      }
    }
    return buffer;
  }

  // Run inference on the image
  Future<void> predict(File image) async {
    if (_interpreter == null || _labels == null) return;
    var input = await preprocessImage(image);
    var output = List.generate(1, (_) => List.filled(_labels!.length, 0.0));
    _interpreter!.run(input.reshape([1, _inputSize, _inputSize, 3]), output);

    var predictions = <String, double>{};
    for (int i = 0; i < _labels!.length; i++) {
      predictions[_labels![i]] = output[0][i] * 100; // percentage
    }
    predictions = Map.fromEntries(
      predictions.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );

    setState(() {
      _predictions = predictions;
      _image = image;
    });
    debugPrint("Predictions: $_predictions");
  }

  // Image selection from camera or gallery
  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: source);
    if (file == null) return;
    File imageFile = File(file.path);
    await predict(imageFile);
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  // When a user wants to share a past result, we push to the ShareResultScreen.
  void _shareResult() {
    if (_image == null || _predictions == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No analysis available to share.")),
      );
      return;
    }
    // Pass the current image file and predictions to the share screen.
    Navigator.pushNamed(context, '/share',
        arguments: {'image': _image, 'predictions': _predictions});
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is logged in
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("dog_chuchuu, a dog breed classifier"),
        actions: [
          // An icon that goes to Login if not logged in,
          // or to the Social Feed if logged in.
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              if (isLoggedIn) {
                Navigator.pushNamed(context, '/feed');
              } else {
                Navigator.pushNamed(context, '/login');
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Display the image (or a placeholder)
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _image != null
                  ? Image.file(_image!, fit: BoxFit.cover)
                  : Image.asset('assets/placeholder.png', fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            // Buttons to select image
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                ),
                ElevatedButton.icon(
                  onPressed: () => pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Gallery"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Show predictions
            _predictions != null
                ? Column(
                    children: _predictions!.entries.map((entry) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(entry.key,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text("${entry.value.toStringAsFixed(1)}%",
                              style: const TextStyle(color: Colors.blue)),
                        ),
                      );
                    }).toList(),
                  )
                : const SizedBox.shrink(),
            const SizedBox(height: 16),
            // Share Button (only available if the user is logged in)
            if (isLoggedIn)
              ElevatedButton.icon(
                onPressed: _shareResult,
                icon: const Icon(Icons.share),
                label: const Text("Share This Result"),
              ),
            if (!isLoggedIn)
              const Text("Log in to share your results!",
                  style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

//
// 2. LOGIN / SIGNUP SCREEN (Firebase Authentication)
//
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLogin = true; // toggle between login and signup
  String email = '';
  String password = '';
  String errorMessage = '';

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    form.save();

    try {
      if (isLogin) {
        // Login
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
      } else {
        // Signup
        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
      }
      Navigator.pop(context); // go back to HomeScreen
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message ?? "Authentication error";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? "Log In" : "Sign Up"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Email Field
              TextFormField(
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
                onSaved: (val) => email = val!.trim(),
                validator: (val) =>
                    (val == null || !val.contains('@')) ? "Enter a valid email" : null,
              ),
              // Password Field
              TextFormField(
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
                onSaved: (val) => password = val!.trim(),
                validator: (val) =>
                    (val == null || val.length < 6) ? "Minimum 6 characters" : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: Text(isLogin ? "Log In" : "Sign Up"),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                  });
                },
                child: Text(isLogin
                    ? "Don’t have an account? Sign up."
                    : "Already have an account? Log in."),
              ),
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(errorMessage,
                      style: const TextStyle(color: Colors.red)),
                )
            ],
          ),
        ),
      ),
    );
  }
}

//
// 3. SHARE RESULT SCREEN
//    This screen lets the user add a caption and then share the result.
//    The image is uploaded to Cloudinary (free tier) and then the post data is stored in Firestore.
//
class ShareResultScreen extends StatefulWidget {
  const ShareResultScreen({Key? key}) : super(key: key);
  @override
  State<ShareResultScreen> createState() => _ShareResultScreenState();
}

class _ShareResultScreenState extends State<ShareResultScreen> {
  final _captionController = TextEditingController();
  bool isUploading = false;

  // Replace these with your Cloudinary details:
  final String cloudName = 'duthpztll';
  final String uploadPreset = 'unsigned_preset';

  // Upload image to Cloudinary and return the secure URL
  Future<String> uploadImageToCloudinary(File imageFile) async {
    var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
    var request = http.MultipartRequest("POST", uri);
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    var response = await request.send();
    if (response.statusCode == 200) {
      final resStr = await response.stream.bytesToString();
      final Map<String, dynamic> jsonResponse = json.decode(resStr);
      return jsonResponse['secure_url'];
    } else {
      throw Exception("Image upload failed");
    }
  }

  // Save the post to Firestore.
  Future<void> _sharePost(File image, Map<String, double> predictions) async {
    setState(() {
      isUploading = true;
    });
    try {
      // Upload image to Cloudinary.
      String imageUrl = await uploadImageToCloudinary(image);
      // Create a post document in Firestore.
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'imageUrl': imageUrl,
        'caption': _captionController.text,
        'predictions': predictions,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Post shared!")));
      Navigator.pop(context); // Return to previous screen.
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve the passed arguments (image & predictions)
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final File? image = args?['image'] as File?;
    final Map<String, double>? predictions =
        args?['predictions'] as Map<String, double>?;

    if (image == null || predictions == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Share Post")),
        body: const Center(child: Text("No data available.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Share Your Result")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Show the image to be shared.
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.file(image, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            // Text field to add a caption.
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                  labelText: "Add a caption", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            isUploading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: () => _sharePost(image, predictions),
                    icon: const Icon(Icons.upload),
                    label: const Text("Share"),
                  )
          ],
        ),
      ),
    );
  }
}

//
// 4. SOCIAL FEED SCREEN
//    This screen displays posts from Firestore in a newsfeed style.
//
class SocialFeedScreen extends StatelessWidget {
  const SocialFeedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen to the 'posts' collection in Firestore (most recent first)
    return Scaffold(
      appBar: AppBar(title: const Text("Social Feed")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading posts."));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data!.docs;
          if (posts.isEmpty) {
            return const Center(child: Text("No posts yet."));
          }
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final imageUrl = post['imageUrl'] as String? ?? '';
              final caption = post['caption'] as String? ?? '';
              final predictions = post['predictions'] as Map<String, dynamic>? ?? {};
              final timestamp = post['timestamp'] != null
                  ? (post['timestamp'] as Timestamp).toDate()
                  : DateTime.now();
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display the image.
                    Image.network(imageUrl),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        caption,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    // Optionally, show top prediction.
                    if (predictions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "Top prediction: " +
                              predictions.entries.first.key +
                              " (${predictions.entries.first.value.toStringAsFixed(1)}%)",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Posted on: ${timestamp.toLocal()}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
