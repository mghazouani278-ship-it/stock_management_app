/// Re-exports generated Flutter localizations (ARB).
/// Use: AppLocalizations.of(context)!.stringKey or context.l10n.stringKey
library;

import 'package:flutter/material.dart';

import '../generated/app_localizations.dart' as gen;

export '../generated/app_localizations.dart';

/// Extension to get non-null AppLocalizations from BuildContext.
extension L10nContext on BuildContext {
  gen.AppLocalizations get l10n => gen.AppLocalizations.of(this)!;
}
