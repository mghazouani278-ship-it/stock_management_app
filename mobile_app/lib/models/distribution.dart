class Distribution {
  final String id;
  final String? serialNumber;
  final String bonAlimentation;
  final String? distributionDate;
  final DistributionRef? project;
  final DistributionRef? store;
  final List<DistributionProduct> products;
  final String status;
  final DistributionUser? validatedBy;
  final dynamic validatedAt;
  final DistributionUser? createdBy;
  final String? notes;
  final dynamic createdAt;
  final dynamic updatedAt;

  Distribution({
    required this.id,
    this.serialNumber,
    required this.bonAlimentation,
    this.distributionDate,
    this.project,
    this.store,
    required this.products,
    required this.status,
    this.validatedBy,
    this.validatedAt,
    this.createdBy,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Distribution.fromJson(Map<String, dynamic> json) {
    return Distribution(
      id: json['id'] ?? json['_id'] ?? '',
      serialNumber: json['serialNumber'] ?? json['serial_number'],
      bonAlimentation: json['bonAlimentation'] ?? json['bon_alimentation'] ?? '',
      distributionDate: json['distributionDate'] ?? json['distribution_date'],
      project: json['project'] != null
          ? DistributionRef.fromJson(Map<String, dynamic>.from(json['project']))
          : null,
      store: json['store'] != null
          ? DistributionRef.fromJson(Map<String, dynamic>.from(json['store']))
          : null,
      products: (json['products'] as List?)?.map((p) => DistributionProduct.fromJson(Map<String, dynamic>.from(p))).toList() ?? [],
      status: json['status'] ?? 'pending',
      validatedBy: json['validatedBy'] != null
          ? DistributionUser.fromJson(Map<String, dynamic>.from(json['validatedBy']))
          : null,
      validatedAt: json['validatedAt'] ?? json['validated_at'],
      createdBy: json['createdBy'] != null
          ? DistributionUser.fromJson(Map<String, dynamic>.from(json['createdBy']))
          : null,
      notes: json['notes'],
      createdAt: json['createdAt'] ?? json['created_at'],
      updatedAt: json['updatedAt'] ?? json['updated_at'],
    );
  }
}

class DistributionRef {
  final String id;
  final String name;
  final String? nameAr;

  DistributionRef({required this.id, required this.name, this.nameAr});

  factory DistributionRef.fromJson(Map<String, dynamic> json) {
    return DistributionRef(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
    );
  }
}

class DistributionUser {
  final String id;
  final String name;
  final String? nameAr;
  final String? email;

  DistributionUser({required this.id, required this.name, this.nameAr, this.email});

  factory DistributionUser.fromJson(Map<String, dynamic> json) {
    return DistributionUser(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
      email: json['email'],
    );
  }
}

class DistributionProduct {
  final String product;
  final String? productName;
  final int quantity;
  final String? color;

  DistributionProduct({required this.product, this.productName, required this.quantity, this.color});

  factory DistributionProduct.fromJson(Map<String, dynamic> json) {
    final p = json['product'];
    final productId = p is Map ? (p['id'] ?? p['_id'] ?? '').toString() : p?.toString() ?? '';
    final productName = p is Map ? (p['name'] as String?) : null;
    return DistributionProduct(
      product: productId,
      productName: productName,
      quantity: json['quantity'] ?? 0,
      color: json['color']?.toString(),
    );
  }
}
