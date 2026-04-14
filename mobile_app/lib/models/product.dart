/// Manufacturer from API / Firestore (several key variants).
String? parseManufacturerField(Map<String, dynamic> json) {
  final v = json['manufacturer'] ?? json['manufacture'] ?? json['Manufacture'];
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

class Product {
  final String id;
  final String name;
  final String? nameAr;
  final String? image;
  final List<String> category;
  /// Arabic category labels (same order as [category] when provided by API).
  final List<String>? categoryAr;
  final String unit;
  final String? manufacturer;
  final String? distributor;
  final String status;
  final List<StoreStock>? stores;
  final List<String> availableColors;
  /// Arabic labels aligned by index with [availableColors].
  final List<String>? availableColorsAr;

  Product({
    required this.id,
    required this.name,
    this.nameAr,
    this.image,
    required this.category,
    this.categoryAr,
    required this.unit,
    this.manufacturer,
    this.distributor,
    required this.status,
    this.stores,
    this.availableColors = const [],
    this.availableColorsAr,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final list = json['stores'] ?? json['depots'];
    final cat = json['category'];
    final categories = cat is List
        ? (cat).map((e) => e.toString()).toList()
        : (cat != null ? [cat.toString()] : <String>[]);
    final colorsRaw = json['available_colors'] ?? json['availableColors'];
    final colors = colorsRaw is List
        ? (colorsRaw).map((e) => e.toString().toLowerCase()).toList()
        : (colorsRaw != null ? [colorsRaw.toString().toLowerCase()] : <String>[]);
    final catArRaw = json['category_ar'] ?? json['categoryAr'];
    List<String>? categoryAr;
    if (catArRaw is List && catArRaw.isNotEmpty) {
      categoryAr = catArRaw.map((e) => e.toString()).toList();
    } else if (catArRaw != null && catArRaw.toString().trim().isNotEmpty) {
      categoryAr = [catArRaw.toString()];
    }
    final colorsArRaw = json['available_colors_ar'] ?? json['availableColorsAr'];
    List<String>? availableColorsAr;
    if (colorsArRaw is List && colorsArRaw.isNotEmpty) {
      availableColorsAr = colorsArRaw.map((e) => e.toString()).toList();
    }
    return Product(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr'] ?? json['name_ar'],
      image: json['image'],
      category: categories,
      categoryAr: categoryAr,
      unit: json['unit'] ?? '',
      manufacturer: parseManufacturerField(json),
      distributor: json['distributor'],
      status: json['status'] ?? 'active',
      stores: list != null
          ? (list as List).map((d) => StoreStock.fromJson(d)).toList()
          : null,
      availableColors: colors,
      availableColorsAr: availableColorsAr,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (nameAr != null && nameAr!.isNotEmpty) 'nameAr': nameAr,
      'image': image,
      'category': category,
      if (categoryAr != null && categoryAr!.isNotEmpty) 'categoryAr': categoryAr,
      'unit': unit,
      'manufacturer': manufacturer,
      'distributor': distributor,
      'status': status,
      'stores': stores?.map((d) => d.toJson()).toList(),
      'availableColors': availableColors,
      if (availableColorsAr != null && availableColorsAr!.isNotEmpty) 'availableColorsAr': availableColorsAr,
    };
  }
}

class StoreStock {
  final String store;
  final int quantity;

  StoreStock({
    required this.store,
    required this.quantity,
  });

  factory StoreStock.fromJson(Map<String, dynamic> json) {
    final s = json['store'] ?? json['depot'];
    return StoreStock(
      store: s != null ? (s['id'] ?? s['_id'] ?? s.toString()) : '',
      quantity: json['quantity'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'store': store,
      'quantity': quantity,
    };
  }
}

