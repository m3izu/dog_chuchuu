// lib/screens/breed_info_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/breed_info_loader.dart';

class BreedInfoScreen extends StatelessWidget {
  /// The WordNet-style ID (the JSON key) for this breed
  final String wordNetId;

  const BreedInfoScreen({Key? key, required this.wordNetId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, BreedMetadata>>(
      future: BreedInfoLoader.loadBreedMetadata(),
      builder: (context, snapshot) {
        // 1) Still loading from asset?
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final allBreeds = snapshot.data!;
        final breed = allBreeds[wordNetId];

        // 2) If this ID isn’t found in JSON
        if (breed == null) {
          return Scaffold(
            appBar: AppBar(title: Text(wordNetId)),
            body: const Center(child: Text("Breed information not found.")),
          );
        }

        // 3) Otherwise show a scrollable details page
        return Scaffold(
          appBar: AppBar(title: Text(breed.name)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breeds often have one “hero” image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    breed.image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  breed.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),

                // Description
                Text(breed.description),
                const SizedBox(height: 16),

                // Origin
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Origin: ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(child: Text(breed.origin)),
                  ],
                ),
                const SizedBox(height: 8),

                // Group
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Group: ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(child: Text(breed.group)),
                  ],
                ),
                const SizedBox(height: 16),

                // “Learn More” button to open Wikipedia link
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text("View on Wikipedia"),
                    onPressed: () async {
                      final url = Uri.parse(breed.wikipedia);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Could not open link")),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
