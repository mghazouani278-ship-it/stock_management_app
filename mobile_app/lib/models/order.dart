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
  /// Expected arrival window in days (1–7) after [orderDate] — promised at create.
  final int? expectedArrivalDays;
  /// YYYY-MM-DD when the order should arrive at the user (promise).
  final String? expectedArrivalDate;
  /// Warehouse distribution calendar day (YYYY-MM-DD).
  final String? distributionDate;
  /// Arrival calendar day at user (YYYY-MM-DD).
  final String? arrivalDate;
  /// Days between distribution and arrival (inclusive). Falls back to [expectedArrivalDays].
  final int? arriveInDays;
  /// User confirmed the delivered order arrived successfully.
  final bool arrivalConfirmed;
  final String? deliveryDate;
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
    this.expectedArrivalDays,
    this.expectedArrivalDate,
    this.distributionDate,
    this.arrivalDate,
    this.arriveInDays,
    this.arrivalConfirmed = false,
    this.deliveryDate,
    this.createdAt,
    this.updatedAt,
  });

  /// Prefer API [arriveInDays]; otherwise inclusive days(distribution → arrival), else promise days.
  int? get displayArriveInDays {
    if (arriveInDays != null && arriveInDays! > 0) return arriveInDays;
    final dist = _ymd(distributionDate) ?? _ymd(deliveryDate);
    final arrive = _ymd(arrivalDate) ?? _ymd(deliveryDate) ?? dist;
    if (dist != null && arrive != null) {
      final span = _diffDays(arrive, dist);
      if (span != null) return span < 0 ? 1 : span + 1;
    }
    return expectedArrivalDays;
  }

  static String? _ymd(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final s = raw.length >= 10 ? raw.substring(0, 10) : raw;
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) ? s : null;
  }

  static int? _diffDays(String laterYmd, String earlierYmd) {
    try {
      final a = laterYmd.split('-').map(int.parse).toList();
      final b = earlierYmd.split('-').map(int.parse).toList();
      final later = DateTime.utc(a[0], a[1], a[2]);
      final earlier = DateTime.utc(b[0], b[1], b[2]);
      return later.difference(earlier).inDays;
    } catch (_) {
      return null;
    }
  }

  /// Days past the expected date while warehouse has not distributed yet.
  /// Hidden after distribution is applied, and not shown before manager approval.
  int? get daysLate {
    final closed = status == 'completed' || status == 'cancelled' || status == 'rejected';
    if (closed) return null;
    if (status != 'approved') return null;
    if (_ymd(distributionDate) != null) return null;
    final expected = expectedArrivalDate ?? _computeExpectedFromOrderDate();
    if (expected == null || expected.isEmpty) return null;
    final today = DateTime.now().toUtc();
    final todayYmd = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (todayYmd.compareTo(expected) <= 0) return null;
    try {
      final parts = expected.split('-').map(int.parse).toList();
      final exp = DateTime.utc(parts[0], parts[1], parts[2]);
      final diff = DateTime.utc(today.year, today.month, today.day).difference(exp).inDays;
      return diff < 1 ? 1 : diff;
    } catch (_) {
      return null;
    }
  }

  String? _computeExpectedFromOrderDate() {
    if (orderDate == null || orderDate!.isEmpty || expectedArrivalDays == null) return null;
    try {
      final parts = orderDate!.split('-').map(int.parse).toList();
      final base = DateTime.utc(parts[0], parts[1], parts[2]);
      final exp = base.add(Duration(days: expectedArrivalDays!));
      return '${exp.year.toString().padLeft(4, '0')}-${exp.month.toString().padLeft(2, '0')}-${exp.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final daysRaw = json['expectedArrivalDays'] ?? json['expected_arrival_days'];
    int? days;
    if (daysRaw is int) {
      days = daysRaw;
    } else if (daysRaw != null) {
      days = int.tryParse(daysRaw.toString());
    }
    final arriveRaw = json['arriveInDays'] ?? json['arrive_in_days'];
    int? arriveDays;
    if (arriveRaw is int) {
      arriveDays = arriveRaw;
    } else if (arriveRaw != null) {
      arriveDays = int.tryParse(arriveRaw.toString());
    }
    String? dateOnly(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      if (s.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) return s.substring(0, 10);
      return s;
    }
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
      expectedArrivalDays: days,
      expectedArrivalDate: dateOnly(json['expectedArrivalDate'] ?? json['expected_arrival_date']),
      distributionDate: dateOnly(json['distributionDate'] ?? json['distribution_date']),
      arrivalDate: dateOnly(json['arrivalDate'] ?? json['arrival_date']),
      arriveInDays: arriveDays,
      arrivalConfirmed: json['arrivalConfirmed'] == true || json['arrival_confirmed'] == true,
      deliveryDate: dateOnly(json['deliveryDate'] ?? json['delivery_date']),
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
  final bool isReplaced;
  final String? originalProductId;
  final String? originalProductName;
  final String? replacementProductId;
  final String? replacementProductName;
  final String? replacedAt;
  final OrderUser? replacedBy;

  OrderProduct({
    required this.product,
    this.name,
    this.unit,
    this.color,
    required this.quantity,
    this.supplementary = false,
    this.projectQuantity = 0,
    this.supplementaryQuantity = 0,
    this.isReplaced = false,
    this.originalProductId,
    this.originalProductName,
    this.replacementProductId,
    this.replacementProductName,
    this.replacedAt,
    this.replacedBy,
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

    final original = json['originalProduct'] ?? json['original_product'];
    final replacement = json['replacementProduct'] ?? json['replacement_product'];
    final replacedByRaw = json['replacedBy'] ?? json['replaced_by'];

    return OrderProduct(
      product: p is Map ? (p['id'] ?? p['_id'] ?? '').toString() : p?.toString() ?? '',
      name: p is Map ? p['name'] : null,
      unit: p is Map ? p['unit']?.toString() : null,
      color: json['color']?.toString() ?? json['variant']?.toString(),
      quantity: qty,
      supplementary: suppFlag || supplementaryQty > 0,
      projectQuantity: projectQty,
      supplementaryQuantity: supplementaryQty,
      isReplaced: json['isReplaced'] == true || json['is_replaced'] == true,
      originalProductId: (json['originalProductId'] ?? json['original_product_id'] ?? (original is Map ? original['id'] : null))?.toString(),
      originalProductName: original is Map ? original['name']?.toString() : null,
      replacementProductId: (json['replacementProductId'] ?? json['replacement_product_id'] ?? (replacement is Map ? replacement['id'] : null))?.toString(),
      replacementProductName: replacement is Map ? replacement['name']?.toString() : null,
      replacedAt: (json['replacedAt'] ?? json['replaced_at'])?.toString(),
      replacedBy: replacedByRaw is Map
          ? OrderUser.fromJson(Map<String, dynamic>.from(replacedByRaw))
          : null,
    );
  }
}
