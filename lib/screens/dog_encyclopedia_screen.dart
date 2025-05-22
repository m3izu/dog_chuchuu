import 'package:flutter/material.dart';
import '../utils/breed_info_loader.dart';
import 'breed_info_screen.dart';

class DogEncyclopediaScreen extends StatelessWidget {
  const DogEncyclopediaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dog Encyclopedia"),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, BreedMetadata>>(
        future: BreedInfoLoader.loadBreedMetadata(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
            return const Center(child: Text("No breed data available."));
          }

          // Turn Map into a sorted list by breed name
          final allBreeds = snapshot.data!;
          final breedList = allBreeds.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.78,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: breedList.length,
              itemBuilder: (context, index) {
                final breed = breedList[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BreedInfoScreen(wordNetId: breed.id),
                      ),
                    );
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Thumbnail image
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                            child: Image.asset(
                              breed.image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.image_not_supported,
                                    size: 48, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),

                        // Breed name
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            breed.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
