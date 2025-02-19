// main.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String backendUrl = "https://dog-chuchub.onrender.com/api";

/// Instance to securely store JWT tokens
final storage = FlutterSecureStorage();

void main() {
  runApp(const DogBreedApp());
}

class DogBreedApp extends StatelessWidget {
  const DogBreedApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dog_chuchuu',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/share': (context) => const ShareResultScreen(),
        '/feed': (context) => const SocialFeedScreen(),
      },
    );
  }
}

/// -------------------------
/// 1. SPLASH SCREEN
/// -------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  @override
  _SplashScreenState createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // After 3 seconds, navigate to the HomeScreen.
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/');
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "dog_chuchuu",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// -------------------------
/// 2. HOME SCREEN – Dog Breed Analyzer & Image Selection
/// -------------------------
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

  /// Load the TFLite model and labels
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      _labels = await loadLabels('assets/labels.txt');
      debugPrint('Model & labels loaded.');
    } catch (e) {
      debugPrint('Error loading model: $e');
    }
  }

  Future<List<String>> loadLabels(String path) async {
    String data = await DefaultAssetBundle.of(context).loadString(path);
    return data.split('\n').map((e) => e.trim()).toList();
  }

  /// Preprocess the image: resize & normalize
  Future<Float32List> preprocessImage(File imageFile) async {
    Uint8List imageBytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception("Failed to decode image");

    img.Image resizedImage =
        img.copyResize(image, width: _inputSize, height: _inputSize);
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

  /// Run inference on the selected image
  Future<void> predict(File image) async {
    if (_interpreter == null || _labels == null) return;
    var input = await preprocessImage(image);
    var output =
        List.generate(1, (_) => List.filled(_labels!.length, 0.0));
    _interpreter!.run(input.reshape([1, _inputSize, _inputSize, 3]), output);

    var predictions = <String, double>{};
    for (int i = 0; i < _labels!.length; i++) {
      predictions[_labels![i]] = output[0][i] * 100;
    }
    predictions = Map.fromEntries(
      predictions.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );
    setState(() {
      _predictions = predictions;
      _image = image;
    });
    debugPrint("Predictions: $_predictions");
  }

  /// Allow the user to pick an image from the camera or gallery
  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: source);
    if (file == null) return;
    File imageFile = File(file.path);
    await predict(imageFile);
  }

  /// Check if user is logged in (i.e. a token exists)
  Future<bool> isLoggedIn() async {
    String? token = await storage.read(key: 'jwt');
    return token != null;
  }

  /// Navigate to the share screen if predictions exist
  void _shareResult() {
    if (_image == null || _predictions == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No analysis available to share.")));
      return;
    }
    Navigator.pushNamed(context, '/share',
        arguments: {'image': _image, 'predictions': _predictions});
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: isLoggedIn(),
      builder: (context, snapshot) {
        bool loggedIn = snapshot.data ?? false;
        return Scaffold(
          appBar: AppBar(
            title: const Text("dog_chuchuu"),
            actions: [
              IconButton(
                icon: const Icon(Icons.person),
                onPressed: () {
                  if (loggedIn) {
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
                // Display the selected image or a placeholder.
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
                // Buttons for image selection.
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
                // Display predictions if available.
                _predictions != null
                    ? Column(
                        children: _predictions!.entries.map((entry) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(entry.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              trailing: Text(
                                  "${entry.value.toStringAsFixed(1)}%",
                                  style: const TextStyle(color: Colors.blue)),
                            ),
                          );
                        }).toList(),
                      )
                    : const SizedBox.shrink(),
                const SizedBox(height: 16),
                // Share button (only available when logged in)
                loggedIn
                    ? ElevatedButton.icon(
                        onPressed: _shareResult,
                        icon: const Icon(Icons.share),
                        label: const Text("Share This Result"),
                      )
                    : const Text("Log in to share your results!",
                        style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// -------------------------
/// 3. LOGIN / SIGNUP SCREEN
/// -------------------------
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
  String errorMessage = '';
  bool isLoading = false;

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    form.save();
    setState(() {
      isLoading = true;
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
        if (isLogin) {
          String token = data['token'];
          await storage.write(key: 'jwt', value: token);
        }
        Navigator.pop(context);
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
      appBar: AppBar(title: Text(isLogin ? "Log In" : "Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
                onSaved: (val) => email = val!.trim(),
                validator: (val) =>
                    (val == null || !val.contains('@'))
                        ? "Enter a valid email"
                        : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
                onSaved: (val) => password = val!.trim(),
                validator: (val) =>
                    (val == null || val.length < 6)
                        ? "Minimum 6 characters"
                        : null,
              ),
              const SizedBox(height: 20),
              isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
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

/// -------------------------
/// 4. SHARE RESULT SCREEN
/// -------------------------
class ShareResultScreen extends StatefulWidget {
  const ShareResultScreen({Key? key}) : super(key: key);
  @override
  State<ShareResultScreen> createState() => _ShareResultScreenState();
}
class _ShareResultScreenState extends State<ShareResultScreen> {
  final _captionController = TextEditingController();
  bool isUploading = false;

  Future<void> _sharePost(File image, Map<String, double> predictions) async {
    setState(() {
      isUploading = true;
    });
    try {
      String? token = await storage.read(key: 'jwt');
      if (token == null) throw Exception("Not authenticated");
      var uri = Uri.parse('$backendUrl/posts');
      var request = http.MultipartRequest("POST", uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['caption'] = _captionController.text
        ..fields['predictions'] = json.encode(predictions)
        ..files.add(await http.MultipartFile.fromPath('image', image.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Post shared!")));
        Navigator.pop(context);
      } else {
        final resBody = await response.stream.bytesToString();
        throw Exception("Error: $resBody");
      }
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
    final args = ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?;
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
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: "Add a caption",
                border: OutlineInputBorder(),
              ),
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

/// -------------------------
/// 5. SOCIAL FEED SCREEN
/// -------------------------
class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({Key? key}) : super(key: key);
  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}
class _SocialFeedScreenState extends State<SocialFeedScreen> {
  Future<List<dynamic>> fetchPosts() async {
    var uri = Uri.parse('$backendUrl/posts');
    var response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load posts");
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Social Feed")),
      body: FutureBuilder<List<dynamic>>(
        future: fetchPosts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading posts."));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data!;
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
              final timestamp = DateTime.parse(post['timestamp']);
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.network(imageUrl),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        caption,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    if (predictions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Builder(
                          builder: (_) {
                            final sortedEntries = predictions.entries.toList()
                              ..sort((a, b) =>
                                  (b.value as num).compareTo(a.value as num));
                            final topEntry = sortedEntries.first;
                            return Text(
                              "Top prediction: ${topEntry.key} (${(topEntry.value as num).toStringAsFixed(1)}%)",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue),
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Posted on: ${timestamp.toLocal()}",
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
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
