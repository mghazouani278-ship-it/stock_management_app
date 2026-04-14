class ReturnModel {
  final String id;
  final ReturnUser? user;
  final ReturnRef? project;
  final List<ReturnProduct> products;
  final String status;
  final ReturnUser? approvedBy;
  final dynamic approvedAt;
  final String? notes;
  final dynamic createdAt;
  final dynamic updatedAt;

  ReturnModel({
    required this.id,
    this.user,
    this.project,
    required this.products,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory ReturnModel.fromJson(Map<String, dynamic> json) {
    return ReturnModel(
      id: json['id'] ?? json['_id'] ?? '',
      user: json['user'] != null
          ? ReturnUser.fromJson(Map<String, dynamic>.from(json['user']))
          : null,
      project: json['project'] != null
          ? ReturnRef.fromJson(Map<String, dynamic>.from(json['project']))
          : null,
      products: (json['products'] as List?)?.map((p) => ReturnProduct.fromJson(Map<String, dynamic>.from(p))).toList() ?? [],
      status: json['status'] ?? 'pending',
      approvedBy: json['approvedBy'] != null
          ? ReturnUser.fromJson(Map<String, dynamic>.from(json['approvedBy']))
          : null,
      approvedAt: json['approvedAt'] ?? json['approved_at'],
      notes: json['notes'],
      createdAt: json['createdAt'] ?? json['created_at'],
      updatedAt: json['updatedAt'] ?? json['updated_at'],
    );
  }
}

class ReturnUser {
  final String id;
  final String name;
  final String? nameAr;
  final String? email;

  ReturnUser({required this.id, required this.name, this.nameAr, this.email});

  factory ReturnUser.fromJson(Map<String, dynamic> json) {
    return ReturnUser(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
      email: json['email'],
    );
  }
}

class ReturnRef {
  final String id;
  final String name;
  final String? nameAr;

  ReturnRef({required this.id, required this.name, this.nameAr});

  factory ReturnRef.fromJson(Map<String, dynamic> json) {
    return ReturnRef(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
    );
  }
}

class ReturnProduct {
  final String product;
  final String? productName;
  final int quantity;
  final String condition;
  /// Color / variant key (aligned with stock lines).
  final String? color;

  ReturnProduct({
    required this.product,
    this.productName,
    required this.quantity,
    this.condition = 'good',
    this.color,
  });

  factory ReturnProduct.fromJson(Map<String, dynamic> json) {
    final p = json['product'];
    final productId = p is Map ? (p['id'] ?? p['_id'] ?? '').toString() : p?.toString() ?? json['product_id']?.toString() ?? '';
    final productName = p is Map ? (p['name'] as String?) : null;
    String? colorStr;
    for (final key in ['color', 'Color', 'variant', 'variance']) {
      final v = json[key];
      if (v != null && v.toString().trim().isNotEmpty) {
        colorStr = v.toString().trim();
        break;
      }
    }
    if (colorStr == null && p is Map) {
      for (final key in ['color', 'Color', 'variant']) {
        final v = p[key];
        if (v != null && v.toString().trim().isNotEmpty) {
          colorStr = v.toString().trim();
          break;
        }
      }
    }
    return ReturnProduct(
      product: productId,
      productName: productName,
      quantity: (json['quantity'] is int) ? json['quantity'] as int : int.tryParse('${json['quantity'] ?? 0}') ?? 0,
      condition: json['condition']?.toString() ?? 'good',
      color: colorStr,
    );
  }
}
