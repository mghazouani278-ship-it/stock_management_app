class DamagedProduct {
  final String id;
  final DamagedRef? product;
  final DamagedRef? project;
  final DamagedRef? store;
  final int quantity;
  final String reason;
  final DamagedUser? reportedBy;
  final DamagedUser? approvedBy;
  final String status;
  final String? notes;
  final dynamic createdAt;
  final dynamic updatedAt;

  DamagedProduct({
    required this.id,
    this.product,
    this.project,
    this.store,
    required this.quantity,
    required this.reason,
    this.reportedBy,
    this.approvedBy,
    required this.status,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory DamagedProduct.fromJson(Map<String, dynamic> json) {
    return DamagedProduct(
      id: json['id'] ?? json['_id'] ?? '',
      product: json['product'] != null
          ? DamagedRef.fromJson(Map<String, dynamic>.from(json['product']))
          : null,
      project: json['project'] != null
          ? DamagedRef.fromJson(Map<String, dynamic>.from(json['project']))
          : null,
      store: json['store'] != null
          ? DamagedRef.fromJson(Map<String, dynamic>.from(json['store']))
          : null,
      quantity: json['quantity'] ?? 0,
      reason: json['reason'] ?? '',
      reportedBy: json['reportedBy'] != null
          ? DamagedUser.fromJson(Map<String, dynamic>.from(json['reportedBy']))
          : null,
      approvedBy: json['approvedBy'] != null
          ? DamagedUser.fromJson(Map<String, dynamic>.from(json['approvedBy']))
          : null,
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      createdAt: json['createdAt'] ?? json['created_at'],
      updatedAt: json['updatedAt'] ?? json['updated_at'],
    );
  }
}

class DamagedRef {
  final String id;
  final String name;
  final String? nameAr;

  DamagedRef({required this.id, required this.name, this.nameAr});

  factory DamagedRef.fromJson(Map<String, dynamic> json) {
    return DamagedRef(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
    );
  }
}

class DamagedUser {
  final String id;
  final String name;
  final String? nameAr;
  final String? email;

  DamagedUser({required this.id, required this.name, this.nameAr, this.email});

  factory DamagedUser.fromJson(Map<String, dynamic> json) {
    return DamagedUser(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
      email: json['email'],
    );
  }
}
