import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart'; // Contains backendUrl, storage, etc.

// For the Hero animation preview
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
    // A full-screen container that closes when tapped outside the image
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

  @override
  void initState() {
    super.initState();
    _postsFuture = _fetchPosts();
  }

  Future<List<dynamic>> _fetchPosts() async {
    final uri = Uri.parse('$backendUrl/posts');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load posts");
    }
  }

  // Helper to show full-screen image with hero animation
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

  @override
  Widget build(BuildContext context) {
    // Force portrait only (you can also do this in Android/iOS configs or use a plugin)
    // For a quick approach, wrap with OrientationBuilder or set in native config.
    return Scaffold(
      // End drawer for the hamburger menu
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
                // Add your settings logic here
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'dog_chuchuu',
                  applicationVersion: '1.0',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                // Handle logout logic
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
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
          // The main feed
          FutureBuilder<List<dynamic>>(
            future: _postsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return const Center(child: Text("Error loading posts."));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No posts yet."));
              }

              final posts = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 100), // Leave space for pinned banner
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return _buildPostItem(post, index);
                },
              );
            },
          ),
          // The pinned banner at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBanner(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post, int index) {
    // Extract relevant info
    final String? imageUrl = post['imageUrl'] as String?;
    final String? caption = post['caption'] as String?;
    final String? userName = post['username'] as String?; 
    // If you store username differently, adjust accordingly
    final String? profilePic = post['profilePicture'] as String?;
    final String? timeStamp = post['timestamp'] as String?;

    // Format time if needed (currently just local time)
    DateTime postedTime = DateTime.parse(timeStamp!);
    String timeString = postedTime.toLocal().toString(); // Simplified; you can format it

    // For the avatar: if no profilePic, use placeholder asset
    ImageProvider avatarProvider;
    if (profilePic != null && profilePic.isNotEmpty) {
      avatarProvider = NetworkImage(profilePic);
    } else {
      avatarProvider = const AssetImage('assets/placeholder_profile.png');
    }

    // Hero tag for image animation
    final heroTag = 'postImage_$index';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row
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
              // Time
              Text(
                timeString, // e.g. "2025-03-05 12:34:56"
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Post image (with hero animation)
          if (imageUrl != null && imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullScreenImage(context, imageUrl, heroTag),
              child: Hero(
                tag: heroTag,
                child: Container(
                  color: Colors.grey.shade300,
                  // Use aspect ratio or fixed height to match your design
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
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
          // Row with paw icon & caption
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.pets, color: Colors.black),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  caption ?? "",
                  style: const TextStyle(fontSize: 14),
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
    // A pinned banner with 3 icons:
    // Left: Paw (no function)
    // Center: Dog-face -> navigate to HomeScreen
    // Right: Person -> navigate to ProfileScreen
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.brown,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Left button: paw icon (no function)
          IconButton(
            icon: const Icon(Icons.pets, color: Colors.white),
            iconSize: 30,
            onPressed: () {
              // No function yet
            },
          ),
          // Center button: dog-face icon -> navigate to home screen
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            iconSize: 30,
            onPressed: () {
              // Navigate to HomeScreen
              // Make sure '/home' is defined in your routes
              Navigator.pushNamed(context, '/');
            },
          ),
          // Right button: user icon -> navigate to profile screen
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
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
