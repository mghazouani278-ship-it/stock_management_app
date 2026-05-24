import '../generated/app_localizations.dart';
import '../models/order.dart';
import 'product_localized.dart';

/// Formats order line quantity for list/detail UI (remaining + supplementary + total).
String formatOrderProductQuantityText(AppLocalizations l10n, OrderProduct p) {
  final unit = formatRawUnitForDisplay(p.unit);
  if (p.hasSupplementaryBreakdown) {
    if (p.projectQuantity <= 0) {
      return l10n.orderQtyAllSupplementary(p.quantity, unit);
    }
    return l10n.orderQtySupplementaryBreakdown(
      p.projectQuantity,
      p.supplementaryQuantity,
      p.quantity,
      unit,
    );
  }
  return '${p.quantity} $unit';
}

/// Same breakdown for order form preview (allocated = remaining from project).
String formatOrderFormQuantityPreview(
  AppLocalizations l10n, {
  required int allocatedRemaining,
  required int orderQty,
  required String unit,
}) {
  if (orderQty > allocatedRemaining && allocatedRemaining >= 0) {
    if (allocatedRemaining <= 0) {
      return l10n.orderQtyAllSupplementary(orderQty, unit);
    }
    return l10n.orderQtySupplementaryBreakdown(
      allocatedRemaining,
      orderQty - allocatedRemaining,
      orderQty,
      unit,
    );
  }
  return l10n.allocatedWithUnit('$allocatedRemaining', unit);
}
