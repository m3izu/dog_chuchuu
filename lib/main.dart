import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

void main() {
  runApp(const DogBreedApp());
}

class DogBreedApp extends StatelessWidget {
  const DogBreedApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'irong buang',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

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

    // Resize to match model's expected input size
    img.Image resizedImage = img.copyResize(image, width: _inputSize, height: _inputSize);

    // Convert image pixels to Float32List
    var buffer = Float32List(_inputSize * _inputSize * 3);
    var pixelIndex = 0;

    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        int pixel = resizedImage.getPixel(x, y);
        buffer[pixelIndex++] = img.getRed(pixel) / 255.0; // Normalize [0,1]
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
    var output = List.generate(1, (_) => List.filled(120, 0.0)); // Model outputs 120 probabilities

    _interpreter!.run(input.reshape([1, _inputSize, _inputSize, 3]), output);

    // Convert output probabilities into a map of breed names & confidence scores
    var predictions = <String, double>{};
    for (int i = 0; i < _labels!.length; i++) {
      predictions[_labels![i]] = output[0][i] * 100; // Convert to percentage
    }

    // Sort predictions by confidence score
    predictions = Map.fromEntries(
      predictions.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );

    setState(() {
      _predictions = predictions;
      _image = image;
    });

    debugPrint("Predictions: $_predictions");
  }

  // Image selection
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("irong buang")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Image Display
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _image != null
                  ? Image.file(_image!, fit: BoxFit.cover)
                  : Image.asset(
                      'assets/placeholder.png',
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 16),
            // Buttons for Image Selection
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
            // Display Predictions
            _predictions != null
                ? Column(
                    children: _predictions!.entries.map((entry) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text("${entry.value.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.blue)),
                        ),
                      );
                    }).toList(),
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
