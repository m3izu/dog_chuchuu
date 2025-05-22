import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../utils/constants.dart';
import 'breed_info_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  Interpreter? _interpreter;
  List<String>? _labels;
  XFile? _capturedImage;
  Map<String, double>? _predictions;
  final int _inputSize = 224;
  bool _isPredicting = false;
  bool _flashOn = false;
  bool _noDogWarning = false;
  double _exposureOffset = 0.0;
  double _minExposureOffset = 0.0;
  double _maxExposureOffset = 0.0;
  double _currentScale = 1.0;
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _loadModel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final camera = widget.cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _cameraController.addListener(() {
      if (mounted) setState(() {});
    });
    await _cameraController.initialize();
    _minExposureOffset = await _cameraController.getMinExposureOffset();
    _maxExposureOffset = await _cameraController.getMaxExposureOffset();
    _cameraController.setExposureOffset(_exposureOffset);
    if (!mounted) return;
    setState(() => _isCameraInitialized = true);
    _startLivePrediction();
  }

  void _startLivePrediction() async {
    while (mounted) {
      if (_cameraController.value.isInitialized && !_isPredicting && _capturedImage == null) {
        try {
          final frame = await _cameraController.takePicture();
          await _predict(File(frame.path), live: true);
        } catch (_) {}
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      _labels = await _loadLabels('assets/labels.txt');
    } catch (e) {
      debugPrint('Model load error: $e');
    }
  }

  Future<List<String>> _loadLabels(String path) async {
    final data = await DefaultAssetBundle.of(context).loadString(path);
    return data.split('\n').map((e) => e.trim()).toList();
  }

  Future<Float32List> _preprocessImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes)!;
    final resized = img.copyResize(image, width: _inputSize, height: _inputSize);
    final buffer = Float32List(_inputSize * _inputSize * 3);
    var idx = 0;
    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final p = resized.getPixel(x, y);
        buffer[idx++] = img.getRed(p) / 255.0;
        buffer[idx++] = img.getGreen(p) / 255.0;
        buffer[idx++] = img.getBlue(p) / 255.0;
      }
    }
    return buffer;
  }

  Future<void> _predict(File file, {bool live = false}) async {
    if (_interpreter == null || _labels == null) return;
    if (!live) setState(() => _isPredicting = true);
    final input = await _preprocessImage(file);
    final output = List.generate(1, (_) => List.filled(_labels!.length, 0.0));
    _interpreter!.run(input.reshape([1, _inputSize, _inputSize, 3]), output);
    final preds = <String, double>{};
    for (var i = 0; i < _labels!.length; i++) {
      preds[_labels![i]] = output[0][i] * 100;
    }
    final sorted = preds.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final map = {for (var e in sorted) e.key: e.value};

    // No-dog detection threshold
    const double noDogThreshold = 60.0; // adjust as needed
    final topConfidence = map.values.first;
    if (topConfidence < noDogThreshold) {
      setState(() {
        _noDogWarning = true;
        _predictions = null;
        _isPredicting = false;
      });
      return;
    }

    setState(() {
      _noDogWarning = false;
      _predictions = map;
      if (!live) _isPredicting = false;
    });
  }

  Future<void> _capture() async {
    if (!_cameraController.value.isInitialized) return;
    _isPredicting = true;
    final imgFile = await _cameraController.takePicture();
    setState(() {
      _capturedImage = imgFile;
      _predictions = null;
    });
    await _predict(File(imgFile.path), live: false);
    _isPredicting = false;
  }

  Future<void> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    _isPredicting = true;
    setState(() {
      _capturedImage = file;
      _predictions = null;
    });
    await _predict(File(file.path), live: false);
    _isPredicting = false;
  }

  void _onScaleStart(ScaleStartDetails details) => _baseScale = _currentScale;
  void _onScaleUpdate(ScaleUpdateDetails details) {
    _currentScale = (_baseScale * details.scale).clamp(1.0, 4.0);
    _cameraController.setZoomLevel(_currentScale);
  }

  void _onTapToFocus(TapDownDetails details, BoxConstraints constraints) {
    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    _cameraController.setFocusPoint(offset);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: _isCameraInitialized
          ? GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CameraPreview(_cameraController),
                  ),
                  LayoutBuilder(
                    builder: (_, constraints) =>
                        GestureDetector(onTapDown: (d) => _onTapToFocus(d, constraints)),
                  ),
                  Positioned(
                    top: 40, left: 16, right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off, color: Colors.green),
                          onPressed: () {
                            _flashOn = !_flashOn;
                            _cameraController.setFlashMode(
                                _flashOn ? FlashMode.torch : FlashMode.off);
                            setState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.wb_sunny, color: Colors.green),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            builder: (_) => Container(
                              color: Colors.black87,
                              padding: const EdgeInsets.all(16),
                              child: Slider(
                                value: _exposureOffset,
                                min: _minExposureOffset,
                                max: _maxExposureOffset,
                                onChanged: (v) {
                                  _exposureOffset = v;
                                  _cameraController.setExposureOffset(v);
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.photo_library, color: Colors.green),
                          onPressed: _pickFromGallery,
                        ),
                        if (_capturedImage != null)
                          IconButton(
                            icon: Icon(
                              Icons.share_outlined,
                              color: (_predictions != null)
                                  ? Colors.green
                                  : Colors.green.withOpacity(0.4),
                            ),
                            onPressed: (_predictions != null)
                                ? () => Navigator.pushNamed(
                                      context, '/share',
                                      arguments: {
                                        'image': File(_capturedImage!.path),
                                        'predictions': _predictions
                                      },
                                    )
                                : null,
                          ),
                      ],
                    ),
                  ),
                  if (_capturedImage != null)
                    Positioned(
                      top: 100, left: 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_capturedImage!.path),
                          width: 80, height: 80, fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  if (_noDogWarning)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.red.withOpacity(0.8),
                        child: const Text(
                          'No dog detected – please point camera at a dog.',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  if (_predictions != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _predictions!.entries.take(3).map((e) {
                            final label = e.key;
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => BreedInfoScreen(wordNetId: label),
                                ));
                              },
                              child: Row(
                                children: [
                                  Expanded(child: Text('$label: ${e.value.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white))),
                                  SizedBox(
                                    width: 100,
                                    child: LinearProgressIndicator(value: e.value / 100),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 40, left: 0, right: 0,
                    child: Center(
                      child: FloatingActionButton(
                        backgroundColor: Colors.green,
                        onPressed: _capture,
                        child: _isPredicting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Icon(Icons.camera_alt,
                                color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
