import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

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
  File? _image;
  List<double>? _predictions;

  // These values should match your model's expected input dimensions
  final int _inputSize = 224;
  final double _mean = 127.5;
  final double _std = 127.5;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  // Load the TFLite model from assets using tflite_flutter.
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/dog_breed_model.tflite');
      debugPrint('Interpreter loaded successfully');
    } catch (e) {
      debugPrint('Error while loading the model: $e');
    }
  }

  // Preprocess the image:
  // 1. Read and decode the image file.
  // 2. Resize it to [_inputSize] x [_inputSize].
  // 3. Normalize pixel values using (_mean, _std) normalization.
  // 4. Build a 4D List with shape [1, _inputSize, _inputSize, 3].
  Future<List<List<List<List<double>>>>> _preProcessImage(File imageFile) async {
    // Read image bytes
    final imageBytes = await imageFile.readAsBytes();
    // Decode the image using the image package
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception("Could not decode image");
    }
    // Resize the image to the desired size
    img.Image resizedImage = img.copyResize(image, width: _inputSize, height: _inputSize);

    // Create a 4D list with shape [1, _inputSize, _inputSize, 3]
    var input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (_) => List.generate(
          _inputSize,
          (_) => List.filled(3, 0.0),
        ),
      ),
    );

    // Populate the list with normalized pixel values.
    // The image package uses ARGB format.
    for (int i = 0; i < _inputSize; i++) {
      for (int j = 0; j < _inputSize; j++) {
        int pixel = resizedImage.getPixel(j, i); // note: (x, y)
        double r = img.getRed(pixel).toDouble();
        double g = img.getGreen(pixel).toDouble();
        double b = img.getBlue(pixel).toDouble();
        input[0][i][j][0] = (r - _mean) / _std;
        input[0][i][j][1] = (g - _mean) / _std;
        input[0][i][j][2] = (b - _mean) / _std;
      }
    }
    return input;
  }

  // Run inference on the preprocessed image and update _predictions.
  Future<void> predict(File image) async {
    if (_interpreter == null) return;

    // Preprocess the image and prepare input tensor.
    var input = await _preProcessImage(image);

    // Retrieve the output shape from the model.
    var outputShape = _interpreter!.getOutputTensor(0).shape; // e.g. [1, numClasses]
    int numClasses = outputShape[1];

    // Create an output buffer as a 2D list of shape [1, numClasses]
    var output = List.generate(1, (_) => List.filled(numClasses, 0.0));

    // Run inference.
    _interpreter!.run(input, output);

    // For simplicity, we assume that output[0] contains the probabilities for each class.
    setState(() {
      _predictions = output[0];
    });
    debugPrint("Inference result: $_predictions");
  }

  // Use ImagePicker to select an image from the specified [source].
  Future<void> pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: source, maxHeight: 300);
    if (file == null) return;

    File imageFile = File(file.path);
    setState(() {
      _image = imageFile;
      _predictions = null;
    });
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
      appBar: AppBar(
        title: const Text("irong buang"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Display the selected image (or a placeholder)
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _image != null
                  ? Image.file(_image!, fit: BoxFit.cover)
                  : Image.network(
                      'https://i.imgur.com/sUFH1Aq.png',
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 16),
            // Buttons to pick an image from camera or gallery
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
            // Display the classification results (predicted class probabilities)
            _predictions != null
                ? Column(
                    children: _predictions!.asMap().entries.map((entry) {
                      int index = entry.key;
                      double confidence = entry.value;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          // If you have a label mapping, you can replace "Class $index"
                          // with the actual dog breed name.
                          title: Text("Class $index"),
                          trailing: Text("${(confidence * 100).toStringAsFixed(1)}%"),
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
