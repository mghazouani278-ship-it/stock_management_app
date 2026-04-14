class Store {
  final String id;
  final String name;
  /// Nom affiché en arabe (API: `name_ar` / `nameAr`).
  final String? nameAr;
  final String? location;
  final String? description;

  Store({
    required this.id,
    required this.name,
    this.nameAr,
    this.location,
    this.description,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
      location: json['location'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (nameAr != null && nameAr!.trim().isNotEmpty) 'nameAr': nameAr,
      'location': location,
      'description': description,
    };
  }
}
