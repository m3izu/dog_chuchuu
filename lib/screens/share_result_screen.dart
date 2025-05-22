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
  bool _isUploading = false;

  Future<void> _sharePost(File image, Map<String, double> predictions) async {
    setState(() => _isUploading = true);
    try {
      final token = await storage.read(key: 'jwt');
      if (token == null) throw Exception('Not authenticated');

      final uri = Uri.parse('$backendUrl/posts');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['caption'] = _captionController.text.trim()
        ..fields['predictions'] = json.encode(predictions)
        ..files.add(await http.MultipartFile.fromPath('image', image.path));

      final resp = await req.send();
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Post shared!')));
        Navigator.pop(context);
      } else {
        final body = await resp.stream.bytesToString();
        throw Exception('Server error: $body');
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final File? image = args?['image'] as File?;
    final Map<String, double>? predictions = args?['predictions'] as Map<String, double>?;

    if (image == null || predictions == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Share Post')),
        body: const Center(child: Text('No data to share.')),
      );
    }

    // Compute top prediction
    final top = predictions.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    final best = top.isNotEmpty ? top.first.key.split('-').last.trim() : 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Your Result'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preview + caption input
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      image,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.pets, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Top breed: $best',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _captionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Caption',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Share button pinned bottom
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.upload, color: Colors.white),
                  label: Text(
                    _isUploading ? 'Sharing...' : 'Share to Feed',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isUploading ? null : () => _sharePost(image, predictions),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
