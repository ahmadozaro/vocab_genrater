import 'package:flutter/material.dart';

class InterestModel {
  final String label;
  final IconData icon;

  const InterestModel({required this.label, required this.icon});
}

const List<InterestModel> kInterests = [
  InterestModel(label: 'Technology', icon: Icons.computer),
  InterestModel(label: 'Sports', icon: Icons.sports_soccer),
  InterestModel(label: 'Music', icon: Icons.music_note),
  InterestModel(label: 'Travel', icon: Icons.flight),
  InterestModel(label: 'Cooking', icon: Icons.restaurant),
  InterestModel(label: 'Science', icon: Icons.science),
  InterestModel(label: 'Business', icon: Icons.business),
  InterestModel(label: 'Art', icon: Icons.palette),
  InterestModel(label: 'Health', icon: Icons.favorite),
  InterestModel(label: 'Literature', icon: Icons.book),
];


InterestModel labelToModel(String label) {
  return kInterests.firstWhere(
    (e) => e.label == label,
    orElse: () => InterestModel(label: label, icon: Icons.tag),
  );
}
