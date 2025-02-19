import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../utils/constants.dart';

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
    final file = await picker.pickImage(source: source);
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
