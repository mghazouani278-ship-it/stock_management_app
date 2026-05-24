class Order {
  final String id;
  final OrderUser? user;
  final OrderRef? project;
  /// Store or depot id chosen when admin approved the order (API: `approvedStoreId`).
  final String? approvedStoreId;
  /// Per-product store from stock (API: `approvedProductStores`).
  final List<OrderApprovedProductStore> approvedProductStores;
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
    this.approvedStoreId,
    this.approvedProductStores = const [],
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
      approvedStoreId: json['approvedStoreId']?.toString() ?? json['approved_store_id']?.toString(),
      approvedProductStores: (json['approvedProductStores'] as List? ?? json['approved_product_stores'] as List?)
              ?.map((e) => OrderApprovedProductStore.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
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

class OrderApprovedProductStore {
  final String product;
  final String store;
  final String? storeName;
  final String? color;

  OrderApprovedProductStore({
    required this.product,
    required this.store,
    this.storeName,
    this.color,
  });

  factory OrderApprovedProductStore.fromJson(Map<String, dynamic> json) {
    return OrderApprovedProductStore(
      product: json['product']?.toString() ?? json['product_id']?.toString() ?? '',
      store: json['store']?.toString() ?? json['store_id']?.toString() ?? '',
      storeName: json['storeName']?.toString() ?? json['store_name']?.toString(),
      color: json['color']?.toString() ?? json['variant']?.toString(),
    );
  }
}

class OrderProduct {
  final String product;
  final String? name;
  final String? unit;
  final String? color;
  final int quantity;
  final bool supplementary;
  final int projectQuantity;
  final int supplementaryQuantity;

  OrderProduct({
    required this.product,
    this.name,
    this.unit,
    this.color,
    required this.quantity,
    this.supplementary = false,
    this.projectQuantity = 0,
    this.supplementaryQuantity = 0,
  });

  /// True when this line has a supplementary part (show remaining + supp + total).
  bool get hasSupplementaryBreakdown => supplementaryQuantity > 0;

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    final p = json['product'];
    final qty = _int(json['quantity']);
    final suppFlag = json['supplementary'] == true;
    final projRaw = json['projectQuantity'] ?? json['project_quantity'];
    final suppRaw = json['supplementaryQuantity'] ?? json['supplementary_quantity'];

    int projectQty;
    int supplementaryQty;

    if (projRaw != null || suppRaw != null) {
      projectQty = _int(projRaw);
      supplementaryQty = _int(suppRaw);
      if (qty > 0 && projectQty + supplementaryQty != qty) {
        if (supplementaryQty > 0) {
          projectQty = qty - supplementaryQty;
        } else if (projectQty > 0) {
          supplementaryQty = qty - projectQty;
        }
      }
    } else if (suppFlag) {
      projectQty = 0;
      supplementaryQty = qty;
    } else {
      projectQty = qty;
      supplementaryQty = 0;
    }

    projectQty = projectQty < 0 ? 0 : projectQty;
    supplementaryQty = supplementaryQty < 0 ? 0 : supplementaryQty;

    return OrderProduct(
      product: p is Map ? (p['id'] ?? p['_id'] ?? '').toString() : p?.toString() ?? '',
      name: p is Map ? p['name'] : null,
      unit: p is Map ? p['unit'] : null,
      color: json['color']?.toString() ?? json['variant']?.toString(),
      quantity: qty,
      supplementary: suppFlag || supplementaryQty > 0,
      projectQuantity: projectQty,
      supplementaryQuantity: supplementaryQty,
    );
  }
}
