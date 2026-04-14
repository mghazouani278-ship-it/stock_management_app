class SupplementaryRequest {
  final String id;
  final SupplementaryRequestUser? user;
  final SupplementaryRequestRef? project;
  final List<SupplementaryRequestProduct> products;
  final String status;
  final String? notes;
  final dynamic createdAt;
  final dynamic updatedAt;

  SupplementaryRequest({
    required this.id,
    this.user,
    this.project,
    required this.products,
    required this.status,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory SupplementaryRequest.fromJson(Map<String, dynamic> json) {
    return SupplementaryRequest(
      id: json['id'] ?? json['_id'] ?? '',
      user: json['user'] != null
          ? SupplementaryRequestUser.fromJson(Map<String, dynamic>.from(json['user']))
          : null,
      project: json['project'] != null
          ? SupplementaryRequestRef.fromJson(Map<String, dynamic>.from(json['project']))
          : null,
      products: (json['products'] as List?)
              ?.map((p) => SupplementaryRequestProduct.fromJson(Map<String, dynamic>.from(p)))
              .toList() ??
          [],
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      createdAt: json['createdAt'] ?? json['created_at'],
      updatedAt: json['updatedAt'] ?? json['updated_at'],
    );
  }
}

class SupplementaryRequestUser {
  final String id;
  final String name;
  final String? nameAr;
  final String? email;

  SupplementaryRequestUser({required this.id, required this.name, this.nameAr, this.email});

  factory SupplementaryRequestUser.fromJson(Map<String, dynamic> json) {
    return SupplementaryRequestUser(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
      email: json['email'],
    );
  }
}

class SupplementaryRequestRef {
  final String id;
  final String name;
  final String? nameAr;

  SupplementaryRequestRef({required this.id, required this.name, this.nameAr});

  factory SupplementaryRequestRef.fromJson(Map<String, dynamic> json) {
    return SupplementaryRequestRef(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
    );
  }
}

class SupplementaryRequestProduct {
  final String product;
  final String? name;
  final String? unit;
  final int quantity;
  final int extraQuantity;
  final int allowedQuantity;

  SupplementaryRequestProduct({
    required this.product,
    this.name,
    this.unit,
    required this.quantity,
    required this.extraQuantity,
    required this.allowedQuantity,
  });

  factory SupplementaryRequestProduct.fromJson(Map<String, dynamic> json) {
    final p = json['product'];
    return SupplementaryRequestProduct(
      product: p is Map ? (p['id'] ?? p['_id'] ?? '').toString() : p?.toString() ?? '',
      name: p is Map ? p['name'] : null,
      unit: p is Map ? p['unit'] : null,
      quantity: json['quantity'] ?? 0,
      extraQuantity: json['extraQuantity'] ?? json['extra_quantity'] ?? 0,
      allowedQuantity: json['allowedQuantity'] ?? json['allowed_quantity'] ?? 0,
    );
  }
}
