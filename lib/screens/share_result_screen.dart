import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

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
