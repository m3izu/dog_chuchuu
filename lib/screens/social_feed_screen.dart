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
  List<dynamic> _posts = [];
  bool _isLoading = true;
  final Map<int, bool> _expandedCaptions = {};

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      String? token = await storage.read(key: 'jwt');
      final uri = Uri.parse('$backendUrl/posts');
      final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });
      if (response.statusCode == 200) {
        setState(() {
          _posts = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load posts');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading posts: \$e')));
    }
  }

  void _refreshFeed() => _loadPosts();

  Future<void> _likePost(String postId, int index) async {
  // Optimistically bump the count in the UI
  setState(() {
    _posts[index]['likeCount'] = (_posts[index]['likeCount'] as int? ?? 0) + 1;
  });

  try {
    final String? token = await storage.read(key: 'jwt');
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse('$backendUrl/posts/$postId/like');
    debugPrint('Liking post at $uri');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    debugPrint('Like response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _posts[index]['likeCount'] = data['likeCount'] as int;
      });
    } else if (response.statusCode == 401) {
      // Token expired or invalid – redirect to login
      ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Session expired. Please log in again.')));
      await storage.delete(key: 'jwt');
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      throw Exception('Server error ${response.statusCode}');
    }
  } catch (e, st) {
    debugPrint('Error in _likePost: $e\n$st');
    // Revert optimistic update
    setState(() {
      _posts[index]['likeCount'] = (_posts[index]['likeCount'] as int) - 1;
    });
    ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Error liking post: $e')));
  }
}

  Future<void> _logout() async {
    await storage.deleteAll();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _showFullScreenImage(
          BuildContext context, String imageUrl, String heroTag) =>
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueGrey),
              child: Text(
                'Group 7 AppDev CS2D 24-25',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF967869)),
              title: const Text('Credits'),
              onTap: () {
                Navigator.pop(context); // close drawer
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Credits'),
                    content: const Text(
                      'Made by Abdulkarim, Araneta, Galendez, Pabellan, Seromines',
                    ),
                    actions: [
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                );
              },
            ),

            // LOGOUT remains
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFF967869)),
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
  backgroundColor: Theme.of(context).primaryColor,  // keeps the same blue as the main screen
  foregroundColor: Colors.black,                     // forces text & icons to be black
  leading: IconButton(
    icon: const Icon(Icons.refresh),
    onPressed: _refreshFeed,
  ),
  title: const Text('Social Feed'),
  actions: [
    Builder(
      builder: (context) => IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => Scaffold.of(context).openEndDrawer(),
      ),
    ),
  ],
),


      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_posts.isEmpty)
            const Center(child: Text('No posts yet.'))
          else
            ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _posts.length,
              itemBuilder: (context, index) =>
                  _buildPostItem(_posts[index], index),
            ),
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
    final String postId = post['_id'] as String;
    final String? imageUrl = post['imageUrl'] as String?;
    final String? caption = post['caption'] as String?;
    final user = post['userId'] as Map<String, dynamic>?;
    final userName = user?['username'] as String?;
    final profilePic = user?['profilePicture'] as String?;
    final timeStamp = post['timestamp'] as String?;
    final predictions = post['predictions'] as Map<String, dynamic>?;
    final bool hasLiked = post['hasLiked'] as bool? ?? false;
    final int likeCount = post['likeCount'] as int? ?? 0;

    DateTime postedTime = DateTime.parse(timeStamp!);
    String timeString = postedTime.toLocal().toString();
    ImageProvider avatarProvider =
        (profilePic != null && profilePic.isNotEmpty)
            ? NetworkImage(profilePic)
            : const AssetImage('assets/placeholder_profile.png');

    String topBreed = 'Unknown Breed';
    if (predictions != null && predictions.isNotEmpty) {
      var sorted = predictions.entries.toList()
        ..sort((a, b) => (b.value as num).compareTo(a.value as num));
      topBreed = sorted.first.key;
      if (topBreed.contains('-')) topBreed = topBreed.split('-').last.trim();
    }

    bool isExpanded = _expandedCaptions[index] ?? false;
    final heroTag = 'postImage_\$index';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: avatarProvider,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  userName ?? 'Unknown User',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                timeString,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (imageUrl != null && imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullScreenImage(
                  context, imageUrl, heroTag),
              child: Hero(
                tag: heroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.grey.shade300,
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 200,
              color: Colors.grey.shade300,
              child: const Center(child: Text('No Image')),  
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
  onTap: hasLiked
      ? null  // disable if already liked
      : () => _likePost(postId, index),
  child: Row(
    children: [
      Image.asset(
        hasLiked
            ? 'assets/icon/heart1.png'
            : 'assets/icon/heart.png',
        width: 24,
        height: 24,
      ),
      const SizedBox(width: 4),
      Text(
        likeCount.toString(),
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold),
      ),
    ],
  ),
),
              const SizedBox(width: 8),
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
                      caption ?? '',
                      style: const TextStyle(fontSize: 14),
                      maxLines: isExpanded ? null : 2,
                      overflow: isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      fontSize: 14),
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
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFF967969),
        borderRadius: BorderRadius.all(Radius.circular(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Image.asset('assets/icon/left.png', width: 40, height: 40),
            onPressed: () => Navigator.pushNamed(context, '/encyclopedia'),
          ),
          IconButton(
            icon: Image.asset('assets/icon/camera.png', width: 120, height: 120),
            iconSize: 70,
            onPressed: () => Navigator.pushNamed(context, '/'),
          ),
          IconButton(
            icon: Image.asset('assets/icon/right.png', width: 40, height: 40),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
    );
  }
}
