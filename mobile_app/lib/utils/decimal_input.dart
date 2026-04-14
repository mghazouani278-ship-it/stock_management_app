/// Parse saisie utilisateur avec **`,`** ou **`.`** comme séparateur décimal (ex. `2,01` ou `2.01`).
num? parseDecimalInput(String? raw) {
  if (raw == null) return null;
  var t = raw.trim().replaceAll(RegExp(r'\s'), '').replaceAll('\u00A0', '');
  if (t.isEmpty) return null;
  t = t.replaceAll(',', '.');
  if (t.split('.').length > 2) return null;
  return num.tryParse(t);
}

/// Affichage compact pour listes / pastilles (évite `2.0` pour les entiers).
String formatQuantityDisplay(num n) {
  final x = n.toDouble();
  if ((x - x.round()).abs() < 1e-9) return '${x.round()}';
  var s = x.toStringAsFixed(4);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  s = s.replaceFirst(RegExp(r'\.$'), '');
  return s;
}
