import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DogEncyclopediaScreen extends StatefulWidget {
  const DogEncyclopediaScreen({Key? key}) : super(key: key);

  @override
  _DogEncyclopediaScreenState createState() => _DogEncyclopediaScreenState();
}

class _DogEncyclopediaScreenState extends State<DogEncyclopediaScreen> {
  List<dynamic> dogBreeds = [];

  @override
  void initState() {
    super.initState();
    loadDogBreeds();
  }

  Future<void> loadDogBreeds() async {
    final String response = await rootBundle.loadString('assets/dog_breeds_clean.json');
    final List<dynamic> data = json.decode(response);
    setState(() {
      dogBreeds = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dog Encyclopedia"),
        centerTitle: true,
      ),
      body: dogBreeds.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(10.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: dogBreeds.length,
                itemBuilder: (context, index) {
                  final breed = dogBreeds[index];
                  return GestureDetector(
                    onTap: () => showBreedDetails(context, breed),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
  child: ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
    child: breed['image'] != null
        ? Image.network(
            breed['image'],
            width: double.infinity,
            fit: BoxFit.cover,
          )
        : Container(
            width: double.infinity,
            color: Colors.grey[300],
            child: const Icon(Icons.image, size: 40, color: Colors.grey),
          ),
  ),
),

                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              breed['name'],
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void showBreedDetails(BuildContext context, Map<String, dynamic> breed) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                breed['name'],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text("Origin: ${breed['origin']}", style: const TextStyle(fontSize: 16)),
              Text("Lifespan: ${breed['lifespan']}", style: const TextStyle(fontSize: 16)),
              Text("Size: ${breed['size']}", style: const TextStyle(fontSize: 16)),
              Text("Fun Fact: ${breed['funFact']}",
                  style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
