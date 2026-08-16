import '../l10n/app_localizations.dart';

String localizedOrderStatus(AppLocalizations l10n, String status) {
  switch (status) {
    case 'approved':
      return l10n.approved;
    case 'completed':
      return l10n.orderStatusCompleted;
    case 'rejected':
    case 'cancelled':
      return l10n.orderStatusRejected;
    case 'returned':
      return 'Returned';
    case 'pending_admin':
      return 'Pending Admin';
    case 'pending_manager':
      return 'Pending Manager';
    case 'pending':
    default:
      return l10n.orderStatusPending;
  }
}
