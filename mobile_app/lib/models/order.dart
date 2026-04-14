class Order {
  final String id;
  final OrderUser? user;
  final OrderRef? project;
  final List<OrderProduct> products;
  final String status;
  final String? notes;
  final String? orderDate;
  final dynamic createdAt;
  final dynamic updatedAt;

  Order({
    required this.id,
    this.user,
    this.project,
    required this.products,
    required this.status,
    this.notes,
    this.orderDate,
    this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? json['_id'] ?? '',
      user: json['user'] != null
          ? OrderUser.fromJson(Map<String, dynamic>.from(json['user']))
          : null,
      project: json['project'] != null
          ? OrderRef.fromJson(Map<String, dynamic>.from(json['project']))
          : null,
      products: (json['products'] as List?)?.map((p) => OrderProduct.fromJson(Map<String, dynamic>.from(p))).toList() ?? [],
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      orderDate: json['orderDate'] ?? json['order_date'],
      createdAt: json['createdAt'] ?? json['created_at'],
      updatedAt: json['updatedAt'] ?? json['updated_at'],
    );
  }
}

class OrderUser {
  final String id;
  final String name;
  final String? nameAr;
  final String? email;

  OrderUser({required this.id, required this.name, this.nameAr, this.email});

  factory OrderUser.fromJson(Map<String, dynamic> json) {
    return OrderUser(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
      email: json['email'],
    );
  }
}

class OrderRef {
  final String id;
  final String name;
  final String? nameAr;

  OrderRef({required this.id, required this.name, this.nameAr});

  factory OrderRef.fromJson(Map<String, dynamic> json) {
    return OrderRef(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
    );
  }
}

class OrderProduct {
  final String product;
  final String? name;
  final String? unit;
  final int quantity;
  final bool supplementary;
  final int projectQuantity;
  final int supplementaryQuantity;

  OrderProduct({
    required this.product,
    this.name,
    this.unit,
    required this.quantity,
    this.supplementary = false,
    this.projectQuantity = 0,
    this.supplementaryQuantity = 0,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    final p = json['product'];
    final qty = json['quantity'] ?? 0;
    final supp = json['supplementary'] == true;
    return OrderProduct(
      product: p is Map ? (p['id'] ?? p['_id'] ?? '').toString() : p?.toString() ?? '',
      name: p is Map ? p['name'] : null,
      unit: p is Map ? p['unit'] : null,
      quantity: qty,
      supplementary: supp,
      projectQuantity: json['projectQuantity'] ?? json['project_quantity'] ?? (supp ? 0 : qty),
      supplementaryQuantity: json['supplementaryQuantity'] ?? json['supplementary_quantity'] ?? (supp ? qty : 0),
    );
  }
}
