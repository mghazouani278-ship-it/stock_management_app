/// MRP report row models.

class MrpRow {
  final String key;
  final String productId;
  final String product;
  final String? productNameAr;
  final String sku;
  final String unit;
  final String? color;
  final List<String> category;
  final List<MrpProjectReq> requiredPerProject;
  final num totalRequired;
  final num reservedQuantity;
  final num remainingQuantity;
  final num warehouseStock;
  final num availableStock;
  final num quantityToPurchase;
  final String purchaseStatus;
  final String? lastUpdated;

  MrpRow({
    required this.key,
    required this.productId,
    required this.product,
    this.productNameAr,
    required this.sku,
    required this.unit,
    this.color,
    this.category = const [],
    this.requiredPerProject = const [],
    required this.totalRequired,
    required this.reservedQuantity,
    required this.remainingQuantity,
    required this.warehouseStock,
    required this.availableStock,
    required this.quantityToPurchase,
    required this.purchaseStatus,
    this.lastUpdated,
  });

  factory MrpRow.fromJson(Map<String, dynamic> json) {
    return MrpRow(
      key: json['key']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      product: json['product']?.toString() ?? '',
      productNameAr: json['productNameAr']?.toString(),
      sku: json['sku']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      color: json['color']?.toString(),
      category: json['category'] is List
          ? (json['category'] as List).map((e) => e.toString()).toList()
          : const [],
      requiredPerProject: json['requiredPerProject'] is List
          ? (json['requiredPerProject'] as List)
              .map((e) => MrpProjectReq.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
      totalRequired: json['totalRequired'] as num? ?? 0,
      reservedQuantity: json['reservedQuantity'] as num? ?? 0,
      remainingQuantity: json['remainingQuantity'] as num? ?? 0,
      warehouseStock: json['warehouseStock'] as num? ?? 0,
      availableStock: json['availableStock'] as num? ?? 0,
      quantityToPurchase: json['quantityToPurchase'] as num? ?? 0,
      purchaseStatus: json['purchaseStatus']?.toString() ?? 'purchase_required',
      lastUpdated: json['lastUpdated']?.toString(),
    );
  }
}

class MrpProjectReq {
  final String projectId;
  final String projectName;
  final String? projectNameAr;
  final num required;
  final num distributed;
  final num remaining;

  MrpProjectReq({
    required this.projectId,
    required this.projectName,
    this.projectNameAr,
    required this.required,
    required this.distributed,
    required this.remaining,
  });

  factory MrpProjectReq.fromJson(Map<String, dynamic> json) {
    return MrpProjectReq(
      projectId: json['projectId']?.toString() ?? '',
      projectName: json['projectName']?.toString() ?? '',
      projectNameAr: json['projectNameAr']?.toString() ?? json['project_name_ar']?.toString(),
      required: json['required'] as num? ?? 0,
      distributed: json['distributed'] as num? ?? 0,
      remaining: json['remaining'] as num? ?? 0,
    );
  }
}

class MrpTotals {
  final int totalProducts;
  final num totalRequired;
  final num totalReserved;
  final num totalRemaining;
  final num totalWarehouseStock;
  final num totalAvailableStock;
  final num totalQuantityToPurchase;

  MrpTotals({
    this.totalProducts = 0,
    this.totalRequired = 0,
    this.totalReserved = 0,
    this.totalRemaining = 0,
    this.totalWarehouseStock = 0,
    this.totalAvailableStock = 0,
    this.totalQuantityToPurchase = 0,
  });

  factory MrpTotals.fromJson(Map<String, dynamic>? json) {
    if (json == null) return MrpTotals();
    return MrpTotals(
      totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
      totalRequired: json['totalRequired'] as num? ?? 0,
      totalReserved: json['totalReserved'] as num? ?? 0,
      totalRemaining: json['totalRemaining'] as num? ?? 0,
      totalWarehouseStock: json['totalWarehouseStock'] as num? ?? 0,
      totalAvailableStock: json['totalAvailableStock'] as num? ?? 0,
      totalQuantityToPurchase: json['totalQuantityToPurchase'] as num? ?? 0,
    );
  }
}
