import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/app_localizations.dart';
import '../models/mrp_row.dart';
import 'l10n_formatters.dart';
import 'product_localized.dart';
import 'project_localized.dart';

enum ProcurementPrintMode {
  allProducts,
  selectedProducts,
  byProject,
}

class MrpReportPdf {
  MrpReportPdf._();

  static String _sanitize(String text) {
    var s = text.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
    s = s.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static String _forPdf(String text) {
    final cleaned = _sanitize(text);
    if (cleaned.isEmpty) return cleaned;
    if (ArabicReshaper.isArabic(cleaned)) {
      return ArabicReshaper.instance.reshape(cleaned);
    }
    return cleaned;
  }

  static String productLabel(MrpRow r, BuildContext context) {
    final ar = r.productNameAr?.trim();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final name = (isAr && ar != null && ar.isNotEmpty)
        ? ar
        : localizedApiProductName(context, r.product);
    if (r.color != null && r.color!.isNotEmpty) {
      return '$name (${localizedVariantOrColorLabel(context, r.color!)})';
    }
    return name;
  }

  static String requiredPerProjectText(MrpRow r, BuildContext context) {
    if (r.requiredPerProject.isEmpty) return '—';
    return r.requiredPerProject.map((p) {
      final n = localizedProjectName(context, p.projectName, nameAr: p.projectNameAr);
      return '$n: ${p.required}';
    }).join('\n');
  }

  static MrpTotals totalsFor(List<MrpRow> rows) {
    return MrpTotals(
      totalProducts: rows.length,
      totalRequired: rows.fold(0, (s, r) => s + r.totalRequired),
      totalReserved: rows.fold(0, (s, r) => s + r.reservedQuantity),
      totalRemaining: rows.fold(0, (s, r) => s + r.remainingQuantity),
      totalWarehouseStock: rows.fold(0, (s, r) => s + r.warehouseStock),
      totalAvailableStock: rows.fold(0, (s, r) => s + r.availableStock),
      totalQuantityToPurchase: rows.fold(0, (s, r) => s + r.quantityToPurchase),
    );
  }

  static Future<void> printReport({
    required BuildContext context,
    required List<MrpRow> rows,
    required String printedBy,
    String? filtersSummary,
    ProcurementPrintMode mode = ProcurementPrintMode.allProducts,
    String? projectId,
    String? projectName,
  }) async {
    if (rows.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    pw.Font baseFont;
    pw.Font boldFont;
    try {
      baseFont = await PdfGoogleFonts.tajawalRegular();
      boldFont = await PdfGoogleFonts.tajawalBold();
    } catch (_) {
      try {
        baseFont = await PdfGoogleFonts.notoSansArabicRegular();
        boldFont = await PdfGoogleFonts.notoSansArabicBold();
      } catch (_) {
        baseFont = await PdfGoogleFonts.notoSansRegular();
        boldFont = await PdfGoogleFonts.notoSansBold();
      }
    }

    final now = DateTime.now();
    final doc = pw.Document();

    final printedAt = L10nFormatters.formatDateTime(context, now);

    if (mode == ProcurementPrintMode.byProject && projectId != null) {
      _addProjectPages(
        context: context,
        doc: doc,
        l10n: l10n,
        rows: rows,
        projectId: projectId,
        projectName: projectName ?? projectId,
        printedBy: printedBy,
        filtersSummary: filtersSummary,
        printedAt: printedAt,
        baseFont: baseFont,
        boldFont: boldFont,
      );
    } else {
      final totals = totalsFor(rows);
      final subtitle = mode == ProcurementPrintMode.selectedProducts
          ? l10n.procurementPdfSelectedSubtitle(rows.length)
          : l10n.procurementPdfAllSubtitle(rows.length);
      _addProductsTablePage(
        context: context,
        doc: doc,
        l10n: l10n,
        rows: rows,
        totals: totals,
        printedBy: printedBy,
        filtersSummary: filtersSummary,
        subtitle: subtitle,
        printedAt: printedAt,
        baseFont: baseFont,
        boldFont: boldFont,
      );
    }

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  static void _addProductsTablePage({
    required BuildContext context,
    required pw.Document doc,
    required AppLocalizations l10n,
    required List<MrpRow> rows,
    required MrpTotals totals,
    required String printedBy,
    String? filtersSummary,
    required String subtitle,
    required String printedAt,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_forPdf(l10n.brandName), style: pw.TextStyle(font: boldFont, fontSize: 16)),
            pw.Text(_forPdf(l10n.procurementPlanning), style: pw.TextStyle(font: boldFont, fontSize: 12)),
            pw.Text(_forPdf(subtitle), style: pw.TextStyle(font: baseFont, fontSize: 9)),
            pw.Text(
              _forPdf(l10n.procurementPdfPrintedBy(printedBy, printedAt)),
              style: pw.TextStyle(font: baseFont, fontSize: 8),
            ),
            if (filtersSummary != null && filtersSummary.isNotEmpty)
              pw.Text(
                _forPdf(l10n.procurementPdfFilters(filtersSummary)),
                style: pw.TextStyle(font: baseFont, fontSize: 8),
              ),
            pw.Divider(),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            _forPdf(l10n.procurementPdfPage(ctx.pageNumber, ctx.pagesCount)),
            style: pw.TextStyle(font: baseFont, fontSize: 8),
          ),
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: [
              l10n.product,
              l10n.procurementColRequiredPerProject,
              l10n.procurementColTotalRequired,
              l10n.procurementColRemaining,
              l10n.procurementColWarehouseStock,
              l10n.procurementColQtyToPurchase,
            ].map(_forPdf).toList(),
            data: rows
                .map(
                  (r) => [
                    productLabel(r, context),
                    requiredPerProjectText(r, context).replaceAll('\n', ' | '),
                    r.totalRequired.toString(),
                    r.remainingQuantity.toString(),
                    r.warehouseStock.toString(),
                    r.quantityToPurchase.toString(),
                  ].map(_forPdf).toList(),
                )
                .toList(),
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 8),
            cellStyle: pw.TextStyle(font: baseFont, fontSize: 7),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.2),
              1: const pw.FlexColumnWidth(2.8),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1.3),
            },
          ),
          pw.SizedBox(height: 12),
          pw.Text(_forPdf(l10n.procurementPdfTotals), style: pw.TextStyle(font: boldFont, fontSize: 10)),
          pw.Text(
            _forPdf(
              '${l10n.procurementTotalsProducts}: ${totals.totalProducts} | '
              '${l10n.procurementTotalsTotalRequired}: ${totals.totalRequired} | '
              '${l10n.procurementTotalsRemaining}: ${totals.totalRemaining} | '
              '${l10n.procurementTotalsWarehouseStock}: ${totals.totalWarehouseStock} | '
              '${l10n.procurementTotalsToPurchase}: ${totals.totalQuantityToPurchase}',
            ),
            style: pw.TextStyle(font: baseFont, fontSize: 8),
          ),
        ],
      ),
    );
  }

  static void _addProjectPages({
    required BuildContext context,
    required pw.Document doc,
    required AppLocalizations l10n,
    required List<MrpRow> rows,
    required String projectId,
    required String projectName,
    required String printedBy,
    String? filtersSummary,
    required String printedAt,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    final projectRows = <List<String>>[];
    num totalRequired = 0;
    num totalRemaining = 0;
    num totalWh = 0;
    num totalPurchase = 0;

    for (final r in rows) {
      final match = r.requiredPerProject.where((p) => p.projectId == projectId).toList();
      if (match.isEmpty) continue;
      final req = match.first;
      totalRequired += req.required;
      totalRemaining += req.remaining;
      totalWh += r.warehouseStock;
      final purchase = (req.remaining - r.warehouseStock) > 0 ? (req.remaining - r.warehouseStock) : 0;
      totalPurchase += purchase;
      projectRows.add([
        productLabel(r, context),
        '${req.required}',
        '${req.remaining}',
        '${r.warehouseStock}',
        '$purchase',
      ].map(_forPdf).toList());
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_forPdf(l10n.brandName), style: pw.TextStyle(font: boldFont, fontSize: 16)),
            pw.Text(_forPdf(l10n.procurementPlanning), style: pw.TextStyle(font: boldFont, fontSize: 12)),
            pw.Text(
              _forPdf(l10n.procurementPdfByProject(projectName)),
              style: pw.TextStyle(font: boldFont, fontSize: 10),
            ),
            pw.Text(
              _forPdf(l10n.procurementPdfPrintedBy(printedBy, printedAt)),
              style: pw.TextStyle(font: baseFont, fontSize: 8),
            ),
            if (filtersSummary != null && filtersSummary.isNotEmpty)
              pw.Text(
                _forPdf(l10n.procurementPdfFilters(filtersSummary)),
                style: pw.TextStyle(font: baseFont, fontSize: 8),
              ),
            pw.Divider(),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            _forPdf(l10n.procurementPdfPage(ctx.pageNumber, ctx.pagesCount)),
            style: pw.TextStyle(font: baseFont, fontSize: 8),
          ),
        ),
        build: (ctx) => [
          if (projectRows.isEmpty)
            pw.Text(
              _forPdf(l10n.procurementPdfNoProductsForProject),
              style: pw.TextStyle(font: baseFont, fontSize: 10),
            )
          else ...[
            pw.TableHelper.fromTextArray(
              headers: [
                l10n.product,
                l10n.required,
                l10n.procurementColRemaining,
                l10n.procurementColWarehouseStock,
                l10n.procurementColQtyToPurchase,
              ].map(_forPdf).toList(),
              data: projectRows,
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 8),
              cellStyle: pw.TextStyle(font: baseFont, fontSize: 7),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              _forPdf(
                '${l10n.procurementPdfTotals} — ${l10n.required}: $totalRequired | '
                '${l10n.procurementTotalsRemaining}: $totalRemaining | '
                '${l10n.procurementTotalsWarehouseStock}: $totalWh | '
                '${l10n.procurementTotalsToPurchase}: $totalPurchase',
              ),
              style: pw.TextStyle(font: baseFont, fontSize: 8),
            ),
          ],
        ],
      ),
    );
  }
}
