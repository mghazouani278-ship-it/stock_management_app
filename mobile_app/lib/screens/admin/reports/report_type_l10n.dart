import '../../../l10n/app_localizations.dart';
import 'reports_screen.dart';

extension ReportTypeL10n on ReportType {
  String titleMenu(AppLocalizations l10n) {
    switch (this) {
      case ReportType.distributions:
        return l10n.reportValidatedDistributionsMenu;
      case ReportType.orders:
        return l10n.orders;
      case ReportType.returns:
        return l10n.reportApprovedReturnsMenu;
      case ReportType.damagedProducts:
        return l10n.damagedProductsMenu;
      case ReportType.stockHistory:
        return l10n.reportStockHistoryMenu;
      case ReportType.projects:
        return l10n.reportProjectsMenu;
    }
  }

  String titleFull(AppLocalizations l10n) {
    switch (this) {
      case ReportType.distributions:
        return l10n.reportValidatedDistributions;
      case ReportType.orders:
        return l10n.orders;
      case ReportType.returns:
        return l10n.reportApprovedReturns;
      case ReportType.damagedProducts:
        return l10n.damagedProducts;
      case ReportType.stockHistory:
        return l10n.reportStockHistory;
      case ReportType.projects:
        return l10n.reportProjects;
    }
  }

  String deleteTypeLabel(AppLocalizations l10n) {
    switch (this) {
      case ReportType.distributions:
        return l10n.reportDeleteTypeDistribution;
      case ReportType.orders:
        return l10n.reportDeleteTypeOrder;
      case ReportType.returns:
        return l10n.reportDeleteTypeReturn;
      case ReportType.damagedProducts:
        return l10n.reportDeleteTypeDamagedProduct;
      case ReportType.stockHistory:
        return l10n.reportDeleteTypeStockEntry;
      case ReportType.projects:
        return l10n.reportProjects;
    }
  }
}
