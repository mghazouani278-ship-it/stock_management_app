import 'product.dart';
import '../utils/decimal_input.dart';

num _quantityFromJson(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  return parseDecimalInput(v.toString()) ?? 0;
}

String? _firstNonEmptyId(String? preferDoc, String? embedded) {
  final x = preferDoc?.trim();
  if (x != null && x.isNotEmpty) return x;
  final y = embedded?.trim();
  if (y != null && y.isNotEmpty) return y;
  return null;
}

/// Same encoding as backend `variantSegmentForStockDocId` (stock doc id suffix).
String _variantSegmentForStockDocId(String variantLabel) {
  var s = variantLabel.trim().toLowerCase();
  if (s.isEmpty) return '';
  s = s.replaceAll('/', '_');
  s = s.replaceAll(RegExp(r'\s+'), '_');
  s = s.replaceAll(RegExp(r'_+'), '_');
  s = s.replaceAll(RegExp(r'^_+|_+$'), '');
  return s;
}

/// Legacy segment extraction when [productId]/[storeId] are unknown (breaks if those ids contain `_`).
String _segmentFallbackSplit(String stockId) {
  final parts = stockId.split('_');
  if (parts.length < 3) return '';
  return parts.sublist(2).join('_');
}

/// Parses stock doc id `productId_storeId_segment` and matches [segment] to a label in [availableColors], else a readable fallback.
/// When [productId] and [storeId] are set, strips `${productId}_${storeId}_` so ids with underscores in product/store parse correctly (same idea as GET `stockToApi` on the server).
String? _resolveVariantFromIdAndColors(
  String stockId,
  List<String> availableColors, {
  String? productId,
  String? storeId,
}) {
  if (stockId.isEmpty) return null;
  String segment;
  final p = productId?.trim();
  final s = storeId?.trim();
  if (p != null && s != null && p.isNotEmpty && s.isNotEmpty) {
    final prefix = '${p}_${s}_';
    if (stockId.startsWith(prefix)) {
      segment = stockId.substring(prefix.length);
    } else if (stockId == '${p}_$s') {
      return null;
    } else {
      segment = _segmentFallbackSplit(stockId);
    }
  } else {
    segment = _segmentFallbackSplit(stockId);
  }
  if (segment.isEmpty) return null;
  for (final c in availableColors) {
    if (_variantSegmentForStockDocId(c) == segment) return c;
  }
  final readable = segment.replaceAll('_', ' ').trim();
  if (readable.isEmpty) return null;
  return readable;
}

/// When API omits variant but stock id encodes the segment, recover label from [product.availableColors].
String? _resolveStockVariant(
  String stockId,
  String? variantApi,
  String? colorApi,
  StockProduct? product,
  StockStore? store,
  String? documentProductId,
  String? documentStoreId,
) {
  final direct = (variantApi != null && variantApi.trim().isNotEmpty)
      ? variantApi.trim()
      : (colorApi != null && colorApi.trim().isNotEmpty ? colorApi.trim() : null);
  if (direct != null) return direct;
  if (stockId.isEmpty) return null;
  final colors = product?.availableColors ?? <String>[];
  return _resolveVariantFromIdAndColors(
    stockId,
    colors,
    productId: _firstNonEmptyId(documentProductId, product?.id),
    storeId: _firstNonEmptyId(documentStoreId, store?.id),
  );
}

class Stock {
  final String id;
  final StockProduct? product;
  final StockStore? store;
  final num quantity;
  /// Product variant (API `variant`; legacy `color` for older responses).
  final String? variant;
  final dynamic updatedAt;
  /// Firestore `product_id` / `store_id` from GET /stock (parse doc id reliably).
  final String? documentProductId;
  final String? documentStoreId;

  Stock({
    required this.id,
    this.product,
    this.store,
    required this.quantity,
    this.variant,
    this.updatedAt,
    this.documentProductId,
    this.documentStoreId,
  });

  /// Variant for this line using [productAvailableColors] from the full `/products` cache when the embedded
  /// product snapshot had no `available_colors` (so [variant] could not be derived in [fromJson]).
  String? variantLabelForProductColors(List<String> productAvailableColors) {
    final v = variant?.trim();
    if (v != null && v.isNotEmpty) return v;
    return _resolveVariantFromIdAndColors(
      id,
      productAvailableColors,
      productId: _firstNonEmptyId(documentProductId, product?.id),
      storeId: _firstNonEmptyId(documentStoreId, store?.id),
    );
  }

  factory Stock.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? json['_id'] ?? '';
    final product = json['product'] != null
        ? StockProduct.fromJson(Map<String, dynamic>.from(json['product']))
        : null;
    final store = json['store'] != null
        ? StockStore.fromJson(Map<String, dynamic>.from(json['store']))
        : null;
    final docPid = json['product_id']?.toString();
    final docSid = json['store_id']?.toString() ?? json['depot_id']?.toString();
    return Stock(
      id: id,
      product: product,
      store: store,
      quantity: _quantityFromJson(json['quantity']),
      variant: _resolveStockVariant(
        id,
        json['variant']?.toString(),
        json['color']?.toString(),
        product,
        store,
        docPid,
        docSid,
      ),
      updatedAt: json['updatedAt'] ?? json['updated_at'],
      documentProductId: docPid,
      documentStoreId: docSid,
    );
  }
}

class StockProduct {
  final String id;
  final String name;
  final String? nameAr;
  final List<String> categories;
  final List<String>? categoryAr;
  final String? unit;
  final String? manufacturer;
  final List<String> availableColors;
  final List<String>? availableColorsAr;

  StockProduct({
    required this.id,
    required this.name,
    this.nameAr,
    this.categories = const [],
    this.categoryAr,
    this.unit,
    this.manufacturer,
    this.availableColors = const [],
    this.availableColorsAr,
  });

  /// Minimal [Product] for localized labels ([ProductLocalized]).
  Product toDisplayProduct() {
    return Product(
      id: id,
      name: name,
      nameAr: nameAr,
      image: null,
      category: categories,
      categoryAr: categoryAr,
      unit: unit ?? '',
      manufacturer: manufacturer,
      distributor: null,
      status: 'active',
      stores: null,
      availableColors: availableColors,
      availableColorsAr: availableColorsAr,
    );
  }

  factory StockProduct.fromJson(Map<String, dynamic> json) {
    final cat = json['category'];
    final categories = cat is List
        ? cat.map((e) => e.toString()).toList()
        : (cat != null ? [cat.toString()] : <String>[]);
    final catArRaw = json['category_ar'] ?? json['categoryAr'];
    List<String>? categoryAr;
    if (catArRaw is List && catArRaw.isNotEmpty) {
      categoryAr = catArRaw.map((e) => e.toString()).toList();
    } else if (catArRaw != null && catArRaw.toString().trim().isNotEmpty) {
      categoryAr = [catArRaw.toString()];
    }
    final colorsRaw = json['available_colors'] ?? json['availableColors'];
    final colors = colorsRaw is List
        ? colorsRaw.map((e) => e.toString().toLowerCase()).toList()
        : (colorsRaw != null ? [colorsRaw.toString().toLowerCase()] : <String>[]);
    final colorsArRaw = json['available_colors_ar'] ?? json['availableColorsAr'];
    List<String>? availableColorsAr;
    if (colorsArRaw is List && colorsArRaw.isNotEmpty) {
      availableColorsAr = colorsArRaw.map((e) => e.toString()).toList();
    }
    final u = json['unit'];
    final unitStr = u is List ? (u.isNotEmpty ? u.first.toString() : null) : u?.toString();
    final manufacturerStr = parseManufacturerField(json);
    return StockProduct(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr'] ?? json['name_ar'],
      categories: categories,
      categoryAr: categoryAr,
      unit: unitStr,
      manufacturer: manufacturerStr,
      availableColors: colors,
      availableColorsAr: availableColorsAr,
    );
  }
}

class StockStore {
  final String id;
  final String name;
  final String? nameAr;

  StockStore({required this.id, required this.name, this.nameAr});

  factory StockStore.fromJson(Map<String, dynamic> json) {
    return StockStore(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr']?.toString() ?? json['name_ar']?.toString(),
    );
  }
}
