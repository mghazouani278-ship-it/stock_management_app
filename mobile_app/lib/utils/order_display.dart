import '../l10n/app_localizations.dart';

String localizedOrderStatus(AppLocalizations l10n, String status) {
  switch (status) {
    case 'approved':
      return l10n.approved;
    case 'completed':
      return l10n.orderStatusCompleted;
    case 'rejected':
      return l10n.orderStatusRejected;
    case 'pending':
    default:
      return l10n.orderStatusPending;
  }
}
