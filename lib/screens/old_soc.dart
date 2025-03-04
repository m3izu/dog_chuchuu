// social_feed_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
// Import the new profile screen.
import 'profile_screen.dart';

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
      appBar: AppBar(
        title: const Text("Social Feed"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          )
        ],
      ),
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
