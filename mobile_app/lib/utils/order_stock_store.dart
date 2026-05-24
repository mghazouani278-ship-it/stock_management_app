import '../models/stock.dart';

String _normColor(String? c) => (c ?? '').trim().toLowerCase();

String orderLineKey(String productId, String? color) {
  final c = _normColor(color);
  return c.isEmpty ? productId : '$productId|$c';
}

bool _stockMatchesLine(Stock s, String productId, String? color) {
  final pid = (s.documentProductId ?? s.product?.id ?? '').trim();
  if (pid != productId) return false;
  final want = _normColor(color);
  final have = _normColor(s.variant);
  if (want.isEmpty) return have.isEmpty;
  return want == have;
}

/// Stock row for this order line (highest quantity if several stores).
Stock? findStockForOrderLine(List<Stock> stocks, String productId, String? color) {
  Stock? best;
  for (final s in stocks) {
    if (!_stockMatchesLine(s, productId, color)) continue;
    if (best == null || s.quantity > best.quantity) {
      best = s;
    }
  }
  return best;
}
