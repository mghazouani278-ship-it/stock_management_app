import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/app_localizations.dart';

/// Printable "Taking Delivery" sheet for one validated distribution.
class TakingDeliveryPdf {
  TakingDeliveryPdf._();

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

  static Future<void> printReport({
    required BuildContext context,
    required Map<String, dynamic> data,
  }) async {
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

    final doc = pw.Document();
    final productRows = (data['productRows'] as List?) ?? const [];
    final timeline = (data['timeline'] as List?) ?? const [];
    final replacements = (data['replacements'] as List?) ?? const [];

    pw.Widget line(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Text(_forPdf(label), style: pw.TextStyle(font: boldFont, fontSize: 10)),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(_forPdf(value.isEmpty ? '—' : value), style: pw.TextStyle(font: baseFont, fontSize: 10)),
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Text(
            _forPdf(l10n.reportTakingDelivery),
            style: pw.TextStyle(font: boldFont, fontSize: 18),
          ),
          pw.SizedBox(height: 12),
          line(l10n.takingDeliveryProjectCreated, '${data['projectCreatedAt'] ?? ''}'),
          line(l10n.project, '${data['projectName'] ?? ''}'),
          line(l10n.takingDeliveryProjectOwner, '${data['projectOwner'] ?? ''}'),
          if ((data['materialRequest'] ?? '').toString().isNotEmpty)
            line(l10n.materialRequest.replaceAll(':', '').trim(), '${data['materialRequest']}'),
          pw.SizedBox(height: 12),
          pw.Text(_forPdf(l10n.productsLabel), style: pw.TextStyle(font: boldFont, fontSize: 12)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [
              _forPdf(l10n.product),
              _forPdf(l10n.requestedQuantityLabel),
              _forPdf(l10n.takingDeliveryQtyDistributed),
              _forPdf(l10n.takingDeliveryQtyRemaining),
            ],
            data: productRows.map((r) {
              final m = Map<String, dynamic>.from(r as Map);
              return [
                _forPdf('${m['name'] ?? ''}'),
                _forPdf('${m['requested'] ?? 0}'),
                _forPdf('${m['distributed'] ?? 0}'),
                _forPdf('${m['remaining'] ?? 0}'),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 9),
            cellStyle: pw.TextStyle(font: baseFont, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          if (replacements.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(_forPdf(l10n.takingDeliveryReplacements), style: pw.TextStyle(font: boldFont, fontSize: 12)),
            pw.SizedBox(height: 4),
            ...replacements.map((r) {
              final m = Map<String, dynamic>.from(r as Map);
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  _forPdf(
                    '${l10n.originalProduct}: ${m['original'] ?? ''}  |  '
                    '${l10n.replacedByProduct}: ${m['replacement'] ?? ''}'
                    '${m['date'] != null && '${m['date']}'.isNotEmpty ? '  |  ${l10n.replacementDate}: ${m['date']}' : ''}',
                  ),
                  style: pw.TextStyle(font: baseFont, fontSize: 9),
                ),
              );
            }),
          ],
          pw.SizedBox(height: 12),
          pw.Text(_forPdf(l10n.takingDeliveryTimeline), style: pw.TextStyle(font: boldFont, fontSize: 12)),
          pw.SizedBox(height: 6),
          ...timeline.map((t) {
            final m = Map<String, dynamic>.from(t as Map);
            return line('${m['label'] ?? ''}', '${m['date'] ?? ''}');
          }),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
}
