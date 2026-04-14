import 'package:flutter/material.dart';

import '../models/damaged_product.dart';
import '../models/store.dart';
import '../models/stock.dart';
import 'embedded_ref_localized.dart';

extension StoreLocalized on Store {
  String displayName(BuildContext context) => embeddedRefDisplayName(context, name, nameAr);
}

extension StockStoreLocalized on StockStore {
  String displayName(BuildContext context) => embeddedRefDisplayName(context, name, nameAr);
}

extension DamagedRefLocalized on DamagedRef {
  String displayName(BuildContext context) => embeddedRefDisplayName(context, name, nameAr);
}
