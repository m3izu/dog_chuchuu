// profile_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool isSaving = false;
  String? currentUsername;
  String? currentProfilePicture; // Store the profile picture URL
  List<dynamic> userPosts = [];
  bool isLoadingPosts = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserInfo();
    _fetchUserPosts();
  }

  Future<void> _loadUserProfile() async {
    // Load the profile picture from secure storage (or API) if saved
    currentProfilePicture = await storage.read(key: 'profilePicture');
    setState(() {});
  }

  Future<void> _loadUserInfo() async {
    // Assume the current username is stored in secure storage.
    String? storedUsername = await storage.read(key: 'username');
    if (storedUsername != null) {
      setState(() {
        currentUsername = storedUsername;
        _usernameController.text = storedUsername;
      });
    }
  }

  Future<void> _fetchUserPosts() async {
    try {
      String? token = await storage.read(key: 'jwt');
      if (token == null) throw Exception("Not authenticated");
      var uri = Uri.parse('$backendUrl/myPosts');
      var response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        setState(() {
          userPosts = json.decode(response.body);
          isLoadingPosts = false;
        });
      } else {
        throw Exception("Failed to load posts");
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoadingPosts = false;
      });
    }
  }

  Future<void> _updateUsername() async {
    setState(() {
      isSaving = true;
    });
    try {
      String? token = await storage.read(key: 'jwt');
      if (token == null) throw Exception("Not authenticated");
      final newUsername = _usernameController.text.trim();
      if (newUsername.isEmpty) throw Exception("Username cannot be empty");
      var uri = Uri.parse('$backendUrl/updateUsername');
      var response = await http.put(uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: json.encode({'username': newUsername}));
      if (response.statusCode == 200) {
        await storage.write(key: 'username', value: newUsername);
        setState(() {
          currentUsername = newUsername;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Username updated!")));
      } else {
        throw Exception("Failed to update username");
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    
    File imageFile = File(pickedFile.path);
    String? token = await storage.read(key: 'jwt');
    if (token == null) return;
    
    var uri = Uri.parse('$backendUrl/updateProfilePicture');
    var request = http.MultipartRequest("PUT", uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));
       
    var response = await request.send();
    if (response.statusCode == 200) {
      final resBody = await response.stream.bytesToString();
      final data = json.decode(resBody);
      setState(() {
        currentProfilePicture = data['profilePicture'];
      });
      await storage.write(key: 'profilePicture', value: currentProfilePicture);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Profile picture updated")));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Error updating profile picture")));
    }
  }

  Future<void> _deleteProfilePicture() async {
    String? token = await storage.read(key: 'jwt');
    if (token == null) return;
    
    var uri = Uri.parse('$backendUrl/deleteProfilePicture');
    var response = await http.delete(uri, headers: {
      'Authorization': 'Bearer $token'
    });
     
    if (response.statusCode == 200) {
      setState(() {
        currentProfilePicture = '';
      });
      await storage.write(key: 'profilePicture', value: '');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Profile picture deleted")));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Error deleting profile picture")));
    }
  }

  Widget _buildProfilePicture() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: currentProfilePicture != null && currentProfilePicture!.isNotEmpty
              ? NetworkImage(currentProfilePicture!)
              : const AssetImage('assets/placeholder_profile.png') as ImageProvider,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _updateProfilePicture,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteProfilePicture,
            ),
          ],
        )
      ],
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Place the profile picture widget at the top
              _buildProfilePicture(),
              const SizedBox(height: 16),
              
              // Display logged-in user information.
              Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: ListTile(
                  leading: const Icon(Icons.account_circle, size: 50),
                  title: Text(currentUsername ?? "No username set"),
                  subtitle: const Text("Logged in user"),
                ),
              ),
              
              // Section to edit username.
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: "Username",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  isSaving
                      ? const CircularProgressIndicator()
                      : IconButton(
                          onPressed: _updateUsername,
                          icon: const Icon(Icons.save),
                        )
                ],
              ),
              
              const SizedBox(height: 24),
              // Recent posts section.
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Your Recent Posts",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              isLoadingPosts
                  ? const CircularProgressIndicator()
                  : userPosts.isEmpty
                      ? const Text("No posts yet.")
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: userPosts.length,
                          itemBuilder: (context, index) {
                            final post = userPosts[index];
                            final imageUrl = post['imageUrl'] as String? ?? '';
                            final caption = post['caption'] as String? ?? '';
                            final timestamp = DateTime.parse(post['timestamp']);
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Image.network(imageUrl),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(caption),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      "Posted on: ${timestamp.toLocal()}",
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(errorMessage, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
