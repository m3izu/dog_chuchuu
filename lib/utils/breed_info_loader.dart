// lib/utils/breed_info_loader.dart

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// A simple model class holding all metadata fields for a breed.
class BreedMetadata {
  final String id;
  final String name;
  final String description;
  final String origin;
  final String group;
  final String image;
  final String wikipedia;

  BreedMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.origin,
    required this.group,
    required this.image,
    required this.wikipedia,
  });

  /// Factory to construct from a JSON map (one entry of breed_info.json).
  factory BreedMetadata.fromJson(String id, Map<String, dynamic> json) {
    return BreedMetadata(
      id: id,
      name: json['name'] as String,
      description: json['description'] as String,
      origin: json['origin'] as String,
      group: json['group'] as String,
      image: json['image'] as String,
      wikipedia: json['wikipedia'] as String,
    );
  }
}

/// A singleton loader that reads and caches the entire breed_info.json.
class BreedInfoLoader {
  static Map<String, BreedMetadata>? _cache;

  /// Reads assets/breed_info.json, parses it, and returns a map from WordNet ID -> BreedMetadata.
  static Future<Map<String, BreedMetadata>> loadBreedMetadata() async {
    if (_cache != null) return _cache!;

    // Load raw JSON string from assets
    final jsonString = await rootBundle.loadString('assets/breed_info.json');
    final Map<String, dynamic> data = json.decode(jsonString) as Map<String, dynamic>;

    // Convert each entry into a BreedMetadata instance
    _cache = {
      for (final id in data.keys)
        id: BreedMetadata.fromJson(id, data[id] as Map<String, dynamic>),
    };
    return _cache!;
  }
}
