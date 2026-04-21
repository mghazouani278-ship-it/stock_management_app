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

  static const String modeFull = 'full';
  static const String modeCreationOnly = 'creationOnly';
  static const String modeLastUpdateOnly = 'lastUpdateOnly';
  static const String modeAllModifications = 'allModifications';

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

  static Future<void> export(
    BuildContext context,
    Map<String, dynamic> apiProject, {
    String mode = modeFull,
    int? historyIndex,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final project = Project.fromJson(Map<String, dynamic>.from(apiProject));
    final createdStr = project.createdAt != null
        ? L10nFormatters.formatDateTime(context, project.createdAt!.toLocal())
        : '—';
    final updatedStr = project.updatedAt != null
        ? L10nFormatters.formatDateTime(context, project.updatedAt!.toLocal())
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

    pw.Widget dateMiniCard(String title, String value) {
      return pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 6),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.7),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              _forPdf(title),
              textDirection: dirFor(title),
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              _forPdf(value),
              textDirection: dirFor(value),
              style: pw.TextStyle(font: baseFont, fontSize: 10),
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

    String historyProductKey(ProjectProduct p) {
      final color = p.color?.trim();
      if (color == null || color.isEmpty) return p.product;
      return '${p.product}:$color';
    }

    int historyQtyFromRaw(dynamic raw) {
      if (raw == null) return 0;
      if (raw is num) return raw.floor().clamp(0, 1 << 30);
      if (raw is Map<String, dynamic>) {
        final value = raw['allowed_quantity'] ?? raw['allowedQuantity'] ?? raw['quantity'];
        return historyQtyFromRaw(value);
      }
      return int.tryParse(raw.toString()) ?? 0;
    }

    List<Map<String, dynamic>> rowsFromProducts(List<ProjectProduct> products) {
      final rows = <Map<String, dynamic>>[];
      for (final p in products) {
        final requested = p.requestedQuantity;
        final distRaw = p.distributedQuantity;
        final distributed = distRaw.clamp(0, requested).toInt();
        final rest = distRaw >= requested ? 0 : requested - distRaw;
        final supplementaryDisplay = distributed >= requested ? p.supplementaryQuantity : 0;
        rows.add({
          'label': productLine(p),
          'requested': requested,
          'distributed': distributed,
          'rest': rest,
          'supplementary': supplementaryDisplay,
        });
      }
      return rows;
    }

    List<Map<String, dynamic>> rowsFromHistorySnapshot(ProjectHistory h) {
      final snap = h.snapshot;
      if (snap == null) return const [];
      final productsRaw = snap['products'];
      if (productsRaw is! Map) return const [];
      final productsMap = Map<String, dynamic>.from(productsRaw);
      final requestedRaw = snap['products_requested'];
      final requestedMap =
          requestedRaw is Map ? Map<String, dynamic>.from(requestedRaw) : <String, dynamic>{};
      final allKeys = <String>{
        ...productsMap.keys.map((k) => k.toString()),
        ...requestedMap.keys.map((k) => k.toString()),
      };
      final knownProducts = <String, ProjectProduct>{
        for (final p in (project.products ?? const <ProjectProduct>[])) historyProductKey(p): p,
      };
      final rows = <Map<String, dynamic>>[];
      for (final key in allKeys) {
        final rawAllowed = productsMap[key];
        final rawReq = requestedMap[key];
        if (rawAllowed == null && rawReq == null) continue;
        final allowed = historyQtyFromRaw(rawAllowed ?? rawReq);
        final requested = historyQtyFromRaw(rawReq ?? rawAllowed);
        final rest = allowed;
        final distributed = requested - rest < 0 ? 0 : requested - rest;
        final p = knownProducts[key];
        final label = p != null ? productLine(p) : key;
        final suppFromP = p?.supplementaryQuantity ?? 0;
        final supplementary = suppFromP > 0 ? suppFromP : (requested > allowed ? requested - allowed : 0);
        rows.add({
          'label': label,
          'requested': requested,
          'distributed': distributed,
          'rest': rest,
          'supplementary': supplementary,
        });
      }
      return rows;
    }

    pw.Widget productsTableFromRows(List<Map<String, dynamic>> rows) {
      if (rows.isEmpty) {
        return pw.Text(
          '—',
          style: pw.TextStyle(font: baseFont, fontSize: 10),
        );
      }
      return pw.Table(
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
              cell(l10n.requestedBoq, bold: true),
              cell(l10n.distributed, bold: true),
              cell(l10n.quantityRest, bold: true),
              cell(l10n.supplementary, bold: true),
            ],
          ),
          ...rows.map((r) => pw.TableRow(
                children: [
                  cell('${r['label'] ?? '—'}'),
                  cell('${r['requested'] ?? 0}'),
                  cell('${r['distributed'] ?? 0}'),
                  cell('${r['rest'] ?? 0}'),
                  cell('${r['supplementary'] ?? 0}'),
                ],
              )),
        ],
      );
    }

    List<pw.Widget> historyWidgets(List<ProjectHistory> entries) {
      if (entries.isEmpty) {
        return [
          pw.Text(
            '—',
            style: pw.TextStyle(font: baseFont, fontSize: 10),
          ),
        ];
      }

      final list = <pw.Widget>[];
      for (final h in entries) {
        final atStr = h.at == null
            ? '—'
            : L10nFormatters.formatDateTime(context, h.at!.toLocal());
        final byName = (h.byName != null && h.byName!.trim().isNotEmpty)
            ? h.byName!.trim()
            : (h.byEmail != null && h.byEmail!.trim().isNotEmpty)
                ? h.byEmail!.trim()
                : '—';
        final changes = h.changes.isEmpty ? 'project' : h.changes.join(', ');

        list.add(
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _forPdf(atStr),
                  textDirection: dirFor(atStr),
                  style: pw.TextStyle(font: boldFont, fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  _forPdf('By: $byName'),
                  textDirection: dirFor(byName),
                  style: pw.TextStyle(font: baseFont, fontSize: 10),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  _forPdf('Changes: $changes'),
                  textDirection: dirFor(changes),
                  style: pw.TextStyle(font: baseFont, fontSize: 10),
                ),
              ],
            ),
          ),
        );
      }
      return list;
    }

    final allHistory = project.history ?? const [];
    final updatedEntries = allHistory
        .where((h) => h.action.toLowerCase() == 'updated')
        .toList()
      ..sort((a, b) {
        final ta = a.at?.millisecondsSinceEpoch ?? 0;
        final tb = b.at?.millisecondsSinceEpoch ?? 0;
        return ta.compareTo(tb);
      });
    final firstUpdate = updatedEntries.isNotEmpty ? updatedEntries.first : null;
    ProjectHistory? singleHistory;
    if (historyIndex != null && historyIndex >= 0 && historyIndex < allHistory.length) {
      singleHistory = allHistory[historyIndex];
    }

    final bool showProjectInfoAndProductsTable =
        mode == modeFull ||
        mode == modeCreationOnly ||
        mode == modeLastUpdateOnly;

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
          if (mode == modeCreationOnly) ...[
            dateMiniCard('1. ${l10n.creationDate.replaceAll(':', '')}', createdStr),
          ] else if (mode == modeLastUpdateOnly) ...[
            if (singleHistory != null) ...[
              pw.Text(
                _forPdf('Project update'),
                textDirection: pw.TextDirection.ltr,
                style: pw.TextStyle(font: boldFont, fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              ...historyWidgets([singleHistory]),
            ] else ...[
              dateMiniCard('2. ${l10n.projectLastEditDateLabel}', updatedStr),
            ],
          ] else if (mode == modeAllModifications) ...[
            pw.Text(
              _forPdf('All modifications'),
              textDirection: pw.TextDirection.ltr,
              style: pw.TextStyle(font: boldFont, fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (firstUpdate != null)
              dateMiniCard(
                '1. ${l10n.reportFirstUpdateDateLabel}',
                firstUpdate.at == null
                    ? '—'
                    : L10nFormatters.formatDateTime(context, firstUpdate.at!.toLocal()),
              ),
            ...historyWidgets(updatedEntries.isNotEmpty ? updatedEntries : allHistory),
            pw.SizedBox(height: 10),
            if (updatedEntries.isEmpty) ...[
              pw.Text(
                _forPdf('Requested / Distributed / Rest / Supplementary'),
                textDirection: pw.TextDirection.ltr,
                style: pw.TextStyle(font: boldFont, fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              productsTableFromRows(rowsFromProducts(project.products ?? const <ProjectProduct>[])),
            ] else ...[
              for (int i = 0; i < updatedEntries.length; i++) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  _forPdf('Update #${i + 1}'),
                  textDirection: pw.TextDirection.ltr,
                  style: pw.TextStyle(font: boldFont, fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                productsTableFromRows(
                  rowsFromHistorySnapshot(updatedEntries[i]).isNotEmpty
                      ? rowsFromHistorySnapshot(updatedEntries[i])
                      : rowsFromProducts(project.products ?? const <ProjectProduct>[]),
                ),
              ],
            ],
          ] else ...[
            dateMiniCard('1. ${l10n.creationDate.replaceAll(':', '')}', createdStr),
            dateMiniCard('2. ${l10n.projectLastEditDateLabel}', updatedStr),
          ],
          if (showProjectInfoAndProductsTable) ...[
            pw.SizedBox(height: 4),
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
            productsTableFromRows(rowsFromProducts(project.products ?? const <ProjectProduct>[])),
          ],
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
