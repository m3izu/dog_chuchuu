import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../utils/constants.dart'; // Contains backendUrl, storage, etc.

// Full-screen image preview with Hero animation.
class ImagePreviewScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const ImagePreviewScreen({
    Key? key,
    required this.imageUrl,
    required this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tap anywhere to go back.
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.black.withOpacity(0.9),
        alignment: Alignment.center,
        child: Hero(
          tag: heroTag,
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({Key? key}) : super(key: key);

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  late Future<List<dynamic>> _postsFuture;

  // Map to track whether a post's caption is expanded.
  final Map<int, bool> _expandedCaptions = {};

  @override
  void initState() {
    super.initState();
    _postsFuture = _fetchPosts();
  }

  Future<List<dynamic>> _fetchPosts() async {
    final uri = Uri.parse('$backendUrl/posts');
    final response = await http.get(uri);
    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load posts");
    }
  }

  // Refresh feed by reassigning the future.
  void _refreshFeed() {
    setState(() {
      _postsFuture = _fetchPosts();
    });
  }

  // Show full-screen image preview using Hero animation.
  void _showFullScreenImage(BuildContext context, String imageUrl, String heroTag) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => ImagePreviewScreen(
          imageUrl: imageUrl,
          heroTag: heroTag,
        ),
      ),
    );
  }

  // Logout function: clears JWT token and navigates to login.
  Future<void> _logout() async {
    await storage.delete(key: 'jwt');
    // Optionally delete other keys such as username or profilePicture.
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // End drawer with creative items including functional logout.
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueGrey),
              child: Text(
                'Surprise Drawer!',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Insert settings logic here.
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help'),
              onTap: () {
                Navigator.pop(context);
                // Insert help logic here.
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        // Replace back button with refresh button.
        leading: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshFeed,
        ),
        title: const Text('Social Feed'),
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // The main scrollable feed.
          FutureBuilder<List<dynamic>>(
            future: _postsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text("Error loading posts: ${snapshot.error}"));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No posts yet."));
              }

              final posts = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 100), // Leave space for pinned banner.
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return _buildPostItem(post, index);
                },
              );
            },
          ),
          // The pinned banner at the bottom.
          Positioned(
            left: 40,
            right: 40,
            bottom: 60,
            child: _buildBottomBanner(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post, int index) {
    // Extract post data.
    final String? imageUrl = post['imageUrl'] as String?;
    final String? caption = post['caption'] as String?;
    // Get the populated user data from "userId".
    final Map<String, dynamic>? user = post['userId'] as Map<String, dynamic>?;
    final String? userName = user != null ? user['username'] as String? : null;
    final String? profilePic = user != null ? user['profilePicture'] as String? : null;
    final String? timeStamp = post['timestamp'] as String?;
    final Map<String, dynamic>? predictions = post['predictions'] as Map<String, dynamic>?;

    // Parse timestamp.
    DateTime postedTime = DateTime.parse(timeStamp!);
    String timeString = postedTime.toLocal().toString();

    // Setup the avatar image: use network image if available, otherwise a placeholder.
    ImageProvider avatarProvider;
    if (profilePic != null && profilePic.isNotEmpty) {
      avatarProvider = NetworkImage(profilePic);
    } else {
      avatarProvider = const AssetImage('assets/placeholder_profile.png');
    }

    // Process predictions to extract the breed with the highest confidence.
    String topBreed = "Unknown Breed";
    if (predictions != null && predictions.isNotEmpty) {
      var sortedEntries = predictions.entries.toList()
        ..sort((a, b) => (b.value as num).compareTo(a.value as num));
      topBreed = sortedEntries.first.key;
      // If the prediction contains a dash "-", show only the part after the dash.
      if (topBreed.contains('-')) {
        topBreed = topBreed.split('-').last.trim();
      }
    }

    // Hero tag for image animation.
    final heroTag = 'postImage_$index';

    // Check if caption is expanded.
    bool isExpanded = _expandedCaptions[index] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row.
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: avatarProvider,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  userName ?? "Unknown User",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Timestamp.
              Text(
                timeString,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Post image with Hero animation and custom border radius.
          if (imageUrl != null && imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullScreenImage(context, imageUrl, heroTag),
              child: Hero(
                tag: heroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.grey.shade300,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 200,
              color: Colors.grey.shade300,
              child: const Center(child: Text("No Image")),
            ),
          const SizedBox(height: 8),
          // Row with custom icon (from assets), expandable caption, and prediction badge.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/icon/heart.png', width: 40, height: 40),
              const SizedBox(width: 8),
              // Expandable caption.
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedCaptions[index] = !isExpanded;
                    });
                  },
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      caption ?? "",
                      style: const TextStyle(fontSize: 14),
                      maxLines: isExpanded ? null : 2,
                      overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Prediction badge.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: Text(
                  topBreed,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const Divider(thickness: 1, height: 24),
        ],
      ),
    );
  }

  Widget _buildBottomBanner(BuildContext context) {
    // Pinned banner with three custom buttons:
    // Left: Custom left icon (no function),
    // Center: Custom camera icon -> navigate to HomeScreen,
    // Right: Custom right icon -> navigate to ProfileScreen.
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFF967969),
        borderRadius: BorderRadius.all(Radius.circular(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Left button: Custom left icon (no function).
          IconButton(
            icon: Image.asset('assets/icon/left.png', width: 40, height: 40),
            iconSize: 30,
            onPressed: () {
              // No function for now.
            },
          ),
          // Center button: Custom camera icon -> navigate to HomeScreen.
          IconButton(
            icon: Image.asset('assets/icon/camera.png', width: 120, height: 120),
            iconSize: 70,
            onPressed: () {
              Navigator.pushNamed(context, '/');
            },
          ),
          // Right button: Custom right icon -> navigate to ProfileScreen.
          IconButton(
            icon: Image.asset('assets/icon/right.png', width: 40, height: 40),
            iconSize: 30,
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
    );
  }
}
