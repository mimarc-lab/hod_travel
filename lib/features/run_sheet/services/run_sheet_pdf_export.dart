import 'dart:typed_data';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/run_sheet_item.dart';
import 'run_sheet_view_mode.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetPdfExport
//
// Generates a role-filtered run sheet PDF and triggers the OS share/print
// sheet via the `printing` package.
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetPdfExport {
  RunSheetPdfExport._();

  // HOD gold accent
  static const _accent      = PdfColor.fromInt(0xFFC9A96E);
  static const _textPrimary = PdfColor.fromInt(0xFF1A1A2E);
  static const _textMuted   = PdfColor.fromInt(0xFF6B7280);
  static const _border      = PdfColor.fromInt(0xFFE5E7EB);
  static const _bgLight     = PdfColor.fromInt(0xFFF9FAFB);

  static final _dateFmt   = DateFormat('EEE, d MMM yyyy');
  static final _timeFmt   = DateFormat('h:mm a');

  /// Role-filter [allItems], build a PDF, and show the OS share sheet.
  static Future<void> share({
    required String            tripName,
    required List<RunSheetItem> allItems,
    required List<TripDay>      days,
    required RunSheetViewMode   viewMode,
  }) async {
    final items = RunSheetRoleFilter.apply(allItems, viewMode);
    final bytes = await _build(
      tripName: tripName,
      items:    items,
      days:     days,
      viewMode: viewMode,
    );
    final filename = '${_sanitize(tripName)}_${viewMode.dbValue}_run_sheet.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  // ── PDF builder ─────────────────────────────────────────────────────────────

  static Future<Uint8List> _build({
    required String            tripName,
    required List<RunSheetItem> items,
    required List<TripDay>      days,
    required RunSheetViewMode   viewMode,
  }) async {
    final doc     = pw.Document();
    final regular = await PdfGoogleFonts.interRegular();
    final medium  = await PdfGoogleFonts.interSemiBold();
    final bold    = await PdfGoogleFonts.interSemiBold();

    final showOps       = RunSheetRoleFilter.showOpsNotes(viewMode);
    final showLogistics = RunSheetRoleFilter.showLogisticsNotes(viewMode);
    final showTransport = RunSheetRoleFilter.showTransportNotes(viewMode);
    final showGuide     = RunSheetRoleFilter.showGuideNotes(viewMode);

    // Group items by day
    final Map<String, List<RunSheetItem>> byDay = {};
    for (final item in items) {
      byDay.putIfAbsent(item.dayId, () => []).add(item);
    }

    // Build body widgets grouped by day
    final body = <pw.Widget>[];
    for (final day in days) {
      final dayItems = byDay[day.id];
      if (dayItems == null || dayItems.isEmpty) continue;

      body.add(_dayHeader(day, bold));
      body.add(pw.SizedBox(height: 8));

      for (final item in dayItems) {
        body.add(_itemBlock(
          item:          item,
          regular:       regular,
          medium:        medium,
          bold:          bold,
          showOps:       showOps,
          showLogistics: showLogistics,
          showTransport: showTransport,
          showGuide:     showGuide,
        ));
        body.add(pw.SizedBox(height: 6));
      }
      body.add(pw.SizedBox(height: 20));
    }

    if (body.isEmpty) {
      body.add(pw.Center(
        child: pw.Text(
          'No items for this role.',
          style: pw.TextStyle(font: regular, color: _textMuted, fontSize: 11),
        ),
      ));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        header:     (ctx) => _pageHeader(tripName, viewMode, ctx, regular, medium, bold),
        footer:     (ctx) => _pageFooter(ctx, regular),
        build:      (_) => body,
      ),
    );

    return doc.save();
  }

  // ── Page header (repeats on each page) ──────────────────────────────────────

  static pw.Widget _pageHeader(
    String tripName,
    RunSheetViewMode viewMode,
    pw.Context ctx,
    pw.Font regular,
    pw.Font medium,
    pw.Font bold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RUN SHEET',
                  style: pw.TextStyle(
                    font:          medium,
                    fontSize:      8,
                    color:         _accent,
                    letterSpacing: 1.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  tripName,
                  style: pw.TextStyle(font: bold, fontSize: 16, color: _textPrimary),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _roleBadge(viewMode, medium),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Exported ${DateFormat('d MMM yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(font: regular, fontSize: 8, color: _textMuted),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: _accent, thickness: 1.5),
        pw.SizedBox(height: 4),
      ],
    );
  }

  // ── Page footer ──────────────────────────────────────────────────────────────

  static pw.Widget _pageFooter(pw.Context ctx, pw.Font regular) {
    return pw.Column(
      children: [
        pw.Divider(color: _border),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'House of Dreammaker — Confidential',
              style: pw.TextStyle(font: regular, fontSize: 7, color: _textMuted),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(font: regular, fontSize: 7, color: _textMuted),
            ),
          ],
        ),
      ],
    );
  }

  // ── Day section header ───────────────────────────────────────────────────────

  static pw.Widget _dayHeader(TripDay day, pw.Font bold) {
    final dateStr = day.date != null ? _dateFmt.format(day.date!) : null;
    final label   = [
      'Day ${day.dayNumber}',
      day.city.toUpperCase(),
    ].join('  ·  ');

    return pw.Container(
      padding:    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color:        _bgLight,
        border:       pw.Border(left: pw.BorderSide(color: _accent, width: 3)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: bold, fontSize: 10, color: _textPrimary),
          ),
          if (dateStr != null)
            pw.Text(
              dateStr,
              style: pw.TextStyle(font: bold, fontSize: 9, color: _textMuted),
            ),
        ],
      ),
    );
  }

  // ── Individual item block ────────────────────────────────────────────────────

  static pw.Widget _itemBlock({
    required RunSheetItem item,
    required pw.Font      regular,
    required pw.Font      medium,
    required pw.Font      bold,
    required bool         showOps,
    required bool         showLogistics,
    required bool         showTransport,
    required bool         showGuide,
  }) {
    final timeStr = item.startTime != null
        ? _fmtTime(item.startTime!)
        : _timeBlockLabel(item.timeBlock);

    return pw.Container(
      padding:    const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border:       pw.Border.all(color: _border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Time column
          pw.SizedBox(
            width: 54,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  timeStr,
                  style: pw.TextStyle(font: bold, fontSize: 9, color: _textPrimary),
                ),
                if (item.endTime != null) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    '→ ${_fmtTime(item.endTime!)}',
                    style: pw.TextStyle(font: regular, fontSize: 8, color: _textMuted),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          // Main content
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title + type badge
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        item.title,
                        style: pw.TextStyle(font: bold, fontSize: 10, color: _textPrimary),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    _typeBadge(item.type, medium),
                  ],
                ),

                // Location
                if (item.location?.isNotEmpty ?? false) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    item.location!,
                    style: pw.TextStyle(font: regular, fontSize: 8.5, color: _textMuted),
                  ),
                ],

                // Supplier
                if (item.supplierName?.isNotEmpty ?? false) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    item.supplierName!,
                    style: pw.TextStyle(font: medium, fontSize: 8.5, color: _textMuted),
                  ),
                ],

                // Contacts
                if (item.primaryContactName?.isNotEmpty ?? false) ...[
                  pw.SizedBox(height: 4),
                  _contactRow(
                    label: 'Contact',
                    name:  item.primaryContactName!,
                    phone: item.primaryContactPhone,
                    regular: regular,
                    medium:  medium,
                  ),
                ],
                if (item.backupContactName?.isNotEmpty ?? false)
                  _contactRow(
                    label: 'Backup',
                    name:  item.backupContactName!,
                    phone: item.backupContactPhone,
                    regular: regular,
                    medium:  medium,
                  ),

                // Responsible person
                if (item.responsibleName?.isNotEmpty ?? false) ...[
                  pw.SizedBox(height: 3),
                  _infoRow('Responsible', item.responsibleName!, regular, medium),
                ],

                // Role-scoped notes
                if (showOps && item.opsNotes?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 5),
                  _noteBlock('OPS NOTE', item.opsNotes!, regular, medium),
                ],
                if (showLogistics && item.logisticsNotes?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 5),
                  _noteBlock('LOGISTICS', item.logisticsNotes!, regular, medium),
                ],
                if (showTransport && item.transportNotes?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 5),
                  _noteBlock('TRANSPORT', item.transportNotes!, regular, medium),
                ],
                if (showGuide && item.guideNotes?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 5),
                  _noteBlock('GUIDE', item.guideNotes!, regular, medium),
                ],

                // Operational instructions
                if (item.operationalInstructions?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 5),
                  _instructionBlock('OPERATIONAL', item.operationalInstructions!, regular, medium),
                ],
                if (item.contingencyInstructions?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 4),
                  _instructionBlock('CONTINGENCY', item.contingencyInstructions!, regular, medium),
                ],
                if (item.escalationInstructions?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 4),
                  _instructionBlock('ESCALATION', item.escalationInstructions!, regular, medium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Small building blocks ────────────────────────────────────────────────────

  static pw.Widget _roleBadge(RunSheetViewMode mode, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color:        _accent,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        mode.label.toUpperCase(),
        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.white, letterSpacing: 0.8),
      ),
    );
  }

  static pw.Widget _typeBadge(ItemType type, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color:        _bgLight,
        border:       pw.Border.all(color: _border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        type.label.toUpperCase(),
        style: pw.TextStyle(font: font, fontSize: 7, color: _textMuted, letterSpacing: 0.5),
      ),
    );
  }

  static pw.Widget _contactRow({
    required String  label,
    required String  name,
    String?          phone,
    required pw.Font regular,
    required pw.Font medium,
  }) {
    return pw.Row(
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(font: medium, fontSize: 8, color: _textMuted),
        ),
        pw.Text(
          name,
          style: pw.TextStyle(font: regular, fontSize: 8, color: _textPrimary),
        ),
        if (phone?.isNotEmpty == true) ...[
          pw.Text(
            '  ·  $phone',
            style: pw.TextStyle(font: regular, fontSize: 8, color: _textMuted),
          ),
        ],
      ],
    );
  }

  static pw.Widget _infoRow(String label, String value, pw.Font regular, pw.Font medium) {
    return pw.Row(
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(font: medium, fontSize: 8, color: _textMuted),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(font: regular, fontSize: 8, color: _textPrimary),
        ),
      ],
    );
  }

  static pw.Widget _noteBlock(String label, String text, pw.Font regular, pw.Font medium) {
    return pw.Container(
      padding:    const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color:        PdfColor.fromHex('#FFFBEB'),
        border:       pw.Border.all(color: PdfColor.fromHex('#FDE68A')),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: medium, fontSize: 7, color: PdfColor.fromHex('#92400E'), letterSpacing: 0.6),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            text,
            style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColor.fromHex('#78350F')),
          ),
        ],
      ),
    );
  }

  static pw.Widget _instructionBlock(String label, String text, pw.Font regular, pw.Font medium) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font:          medium,
            fontSize:      7.5,
            color:         _textMuted,
            letterSpacing: 0.6,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          text,
          style: pw.TextStyle(font: regular, fontSize: 8.5, color: _textPrimary),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _fmtTime(TimeOfDay t) {
    final now  = DateTime.now();
    final dt   = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return _timeFmt.format(dt);
  }

  static String _timeBlockLabel(TimeBlock block) => switch (block) {
    TimeBlock.morning   => 'Morning',
    TimeBlock.afternoon => 'Afternoon',
    TimeBlock.evening   => 'Evening',
    TimeBlock.allDay    => 'All Day',
  };

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
}
