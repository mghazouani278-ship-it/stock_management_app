import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/app_localizations.dart';
import '../models/user.dart';
import '../utils/l10n_formatters.dart';
import '../utils/product_localized.dart';
import '../utils/project_localized.dart';

/// Builds a printable PDF snapshot for a project (API `/projects` payload shape).
///
/// Le moteur [pdf] ne fait pas le shaping OpenType arabe : on utilise
/// [arabic_reshaper] pour les formes de présentation, et une police unique
/// (Tajawal) partout pour éviter les tofu / fallbacks (voir dart_pdf #1743).
class ProjectReportPdf {
  ProjectReportPdf._();

  /// Sauts de ligne et certains caractères invisibles se dessinent souvent en « tofu »
  /// (carré) dans un seul [pw.Text] — on les neutralise avant rendu.
  static String _sanitizeForPdf(String text) {
    if (text.isEmpty) return text;
    var s = text.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
    s = s.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    // Remove bidi/format controls that the pdf engine can render as tofu boxes.
    s = s.replaceAll(RegExp(r'[\u200E\u200F\u061C\u202A-\u202E\u2066-\u2069]'), '');
    s = s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Prépare une chaîne pour un moteur PDF LTR sans shaping natif.
  static String _forPdf(String text) {
    final cleaned = _sanitizeForPdf(text);
    if (cleaned.isEmpty) return cleaned;
    if (ArabicReshaper.isArabic(cleaned)) {
      return ArabicReshaper.instance.reshape(cleaned);
    }
    return cleaned;
  }

  static Future<void> export(BuildContext context, Map<String, dynamic> apiProject) async {
    final l10n = AppLocalizations.of(context)!;
    final project = Project.fromJson(Map<String, dynamic>.from(apiProject));
    final createdStr = project.createdAt != null
        ? L10nFormatters.formatDateTime(context, project.createdAt!.toLocal())
        : '—';
    final owner = project.displayOwner(context) ?? '—';
    final desc = project.displayDescription(context);
    final descStr = (desc != null && desc.isNotEmpty) ? desc : '—';
    final name = project.displayName(context);

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

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );

    pw.TextDirection dirFor(String s) {
      if (RegExp(r'^[0-9]+$').hasMatch(s.trim())) return pw.TextDirection.ltr;
      if (ArabicReshaper.isArabic(s)) return pw.TextDirection.rtl;
      return pw.TextDirection.ltr;
    }

    pw.Widget cell(String text, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            _forPdf(text),
            textDirection: dirFor(text),
            style: pw.TextStyle(
              font: bold ? boldFont : baseFont,
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );

    pw.Widget pdfLine(String label, String value) {
      final v = _forPdf(value);
      final l = _forPdf(label);
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '$l: ',
              style: pw.TextStyle(font: boldFont, fontSize: 10, fontWeight: pw.FontWeight.bold),
              textDirection: dirFor(label),
            ),
            pw.Expanded(
              child: pw.Text(
                v,
                style: pw.TextStyle(font: baseFont, fontSize: 10),
                textDirection: dirFor(value),
              ),
            ),
          ],
        ),
      );
    }

    String productLine(ProjectProduct p) {
      final raw = p.productName ?? p.product;
      final n = raw.trim().isNotEmpty ? localizedApiProductName(context, raw) : raw;
      if (p.color != null && p.color!.isNotEmpty) {
        return '$n (${localizedVariantOrColorLabel(context, p.color!)})';
      }
      return n;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          pw.Text(
            _forPdf(l10n.reportProjects),
            textDirection: dirFor(l10n.reportProjects),
            style: pw.TextStyle(font: boldFont, fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pdfLine(l10n.creationDate, createdStr),
          pdfLine(l10n.project, name),
          pdfLine(l10n.owner, owner),
          pdfLine(l10n.description, descStr),
          pw.SizedBox(height: 16),
          pw.Text(
            _forPdf(l10n.products),
            textDirection: dirFor(l10n.products),
            style: pw.TextStyle(font: boldFont, fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (project.products == null || project.products!.isEmpty)
            pw.Text(
              '—',
              style: pw.TextStyle(font: baseFont, fontSize: 10),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3.2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    cell(l10n.reportFieldProduct, bold: true),
                    cell(l10n.requested, bold: true),
                    cell(l10n.distributed, bold: true),
                    cell(l10n.quantityRest, bold: true),
                    cell(l10n.supplementary, bold: true),
                  ],
                ),
                ...project.products!.map((p) {
                  final requested = p.requestedQuantity;
                  final remaining = p.allowedQuantity;
                  final distQty = (requested - remaining) < 0 ? 0 : (requested - remaining);
                  final line = productLine(p);
                  return pw.TableRow(
                    children: [
                      cell(line),
                      cell('$requested'),
                      cell('$distQty'),
                      cell('$remaining'),
                      cell('${p.supplementaryQuantity}'),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );

    final fileSafe = '${project.id}_project_report.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: fileSafe,
    );
  }
}
