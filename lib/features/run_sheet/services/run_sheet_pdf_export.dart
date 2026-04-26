import 'dart:typed_data';
import 'package:flutter/material.dart' show TimeOfDay, DayPeriod;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/run_sheet_item.dart';
import '../../../data/models/run_sheet_view_mode.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetPdfExport
//
// Generates a role-filtered run sheet PDF matching the HOD Travel client
// itinerary design (cream bg, gold accent, Inter fonts, white item cards).
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetPdfExport {
  RunSheetPdfExport._();

  // ── Palette (matches PdfExportService) ──────────────────────────────────────
  static const _gold   = PdfColor.fromInt(0xFFC9A96E);
  static const _ink    = PdfColor.fromInt(0xFF111318);
  static const _muted  = PdfColor.fromInt(0xFF9CA3AF);
  static const _border = PdfColor.fromInt(0xFFE8E7E5);
  static const _bg     = PdfColor.fromInt(0xFFF8F7F5);
  static const _white  = PdfColors.white;

  static final _dateLong  = DateFormat('EEEE, d MMMM yyyy');
  static final _dateShort = DateFormat('d MMMM yyyy');

  // ── Entry point ──────────────────────────────────────────────────────────────

  // ── Inline role filter (self-contained, no external service dependency) ────────

  static List<RunSheetItem> _filterByRole(
      List<RunSheetItem> items, RunSheetViewMode viewMode) {
    return switch (viewMode) {
      RunSheetViewMode.driver =>
          items.where((i) =>
              i.type == ItemType.transport ||
              i.type == ItemType.flight).toList(),
      RunSheetViewMode.guide =>
          items.where((i) => i.type == ItemType.experience).toList(),
      _ => List<RunSheetItem>.from(items), // director & operations see all
    };
  }

  static bool _showOps(RunSheetViewMode m) =>
      m == RunSheetViewMode.director || m == RunSheetViewMode.operations;
  static bool _showLogistics(RunSheetViewMode m) =>
      m != RunSheetViewMode.guide;
  static bool _showTransport(RunSheetViewMode m) =>
      m == RunSheetViewMode.director ||
      m == RunSheetViewMode.driver ||
      m == RunSheetViewMode.operations;
  static bool _showGuide(RunSheetViewMode m) =>
      m == RunSheetViewMode.director ||
      m == RunSheetViewMode.guide ||
      m == RunSheetViewMode.operations;

  // ── Entry point ──────────────────────────────────────────────────────────────

  static Future<void> share({
    required String             tripName,
    required List<RunSheetItem> allItems,
    required List<TripDay>      days,
    required RunSheetViewMode   viewMode,
  }) async {
    final items = _filterByRole(allItems, viewMode);
    final bytes = await _build(
      tripName: tripName,
      items:    items,
      days:     days,
      viewMode: viewMode,
    );
    final filename = '${_sanitize(tripName)}_${viewMode.dbValue}_run_sheet.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  // ── Build document ───────────────────────────────────────────────────────────

  static Future<Uint8List> _build({
    required String             tripName,
    required List<RunSheetItem> items,
    required List<TripDay>      days,
    required RunSheetViewMode   viewMode,
  }) async {
    final doc = pw.Document(
      title:   '$tripName — Run Sheet',
      author:  'HOD Travel',
      subject: '${viewMode.label} Run Sheet',
    );

    final font      = await PdfGoogleFonts.interRegular();
    final fontBold  = await PdfGoogleFonts.interSemiBold();
    final fontLight = await PdfGoogleFonts.interLight();

    final baseTheme = pw.ThemeData(
      defaultTextStyle: pw.TextStyle(font: font, fontSize: 10, color: _ink),
    );

    final showOps       = _showOps(viewMode);
    final showLogistics = _showLogistics(viewMode);
    final showTransport = _showTransport(viewMode);
    final showGuide     = _showGuide(viewMode);

    // Group items by day
    final Map<String, List<RunSheetItem>> byDay = {};
    for (final item in items) {
      byDay.putIfAbsent(item.dayId, () => []).add(item);
    }

    // ── Cover page ─────────────────────────────────────────────────────────────
    doc.addPage(
      pw.Page(
        theme:      baseTheme,
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.all(0),
        build:      (_) => _buildCoverPage(
          tripName:  tripName,
          viewMode:  viewMode,
          days:      days,
          itemCount: items.length,
          fontBold:  fontBold,
          fontLight: fontLight,
          font:      font,
        ),
      ),
    );

    // ── Content pages (all days in one MultiPage) ──────────────────────────────
    final sortedDays = List<TripDay>.from(days)
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

    final body = <pw.Widget>[];
    for (final day in sortedDays) {
      final dayItems = byDay[day.id];
      if (dayItems == null || dayItems.isEmpty) continue;

      body.addAll(_buildDaySection(
        day:          day,
        items:        dayItems,
        font:         font,
        fontBold:     fontBold,
        fontLight:    fontLight,
        showOps:      showOps,
        showLogistics: showLogistics,
        showTransport: showTransport,
        showGuide:    showGuide,
      ));
    }

    if (body.isEmpty) {
      body.add(pw.Center(
        child: pw.Text(
          'No items for this role.',
          style: pw.TextStyle(font: font, fontSize: 11, color: _muted),
        ),
      ));
    }

    doc.addPage(
      pw.MultiPage(
        theme:      baseTheme,
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 48),
        header:     (ctx) => _buildPageHeader(tripName, viewMode, font, fontBold),
        footer:     (ctx) => _buildPageFooter(ctx, font),
        build:      (_)   => body,
      ),
    );

    return doc.save();
  }

  // ── Cover page ───────────────────────────────────────────────────────────────

  static pw.Widget _buildCoverPage({
    required String           tripName,
    required RunSheetViewMode viewMode,
    required List<TripDay>    days,
    required int              itemCount,
    required pw.Font          fontBold,
    required pw.Font          fontLight,
    required pw.Font          font,
  }) {
    final sortedDays = List<TripDay>.from(days)
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

    final firstDate = sortedDays.firstWhere(
      (d) => d.date != null, orElse: () => sortedDays.first).date;
    final lastDate  = sortedDays.lastWhere(
      (d) => d.date != null, orElse: () => sortedDays.last).date;

    final dateStr = (firstDate != null && lastDate != null)
        ? '${DateFormat('d MMMM').format(firstDate)} – ${_dateShort.format(lastDate)}'
        : '';

    final cities = sortedDays.map((d) => d.city).toSet().toList();

    return pw.Stack(
      children: [
        // Cream background
        pw.Positioned.fill(
          child: pw.Container(color: _bg),
        ),
        // Gold left strip
        pw.Positioned(
          left: 0, top: 0, bottom: 0,
          child: pw.Container(width: 6, color: _gold),
        ),
        // Content
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(56, 80, 56, 56),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('HOD TRAVEL',
                  style: pw.TextStyle(
                    font: fontBold, fontSize: 9, color: _gold,
                    letterSpacing: 2.5)),
              pw.SizedBox(height: 8),
              pw.Container(width: 40, height: 1, color: _gold),
              pw.SizedBox(height: 48),

              pw.Text('RUN SHEET',
                  style: pw.TextStyle(
                    font: font, fontSize: 11, color: _muted,
                    letterSpacing: 2)),
              pw.SizedBox(height: 12),
              pw.Text(tripName,
                  style: pw.TextStyle(
                    font: fontBold, fontSize: 36, color: _ink,
                    height: 1.2)),
              pw.SizedBox(height: 24),

              if (dateStr.isNotEmpty) ...[
                pw.Text(dateStr,
                    style: pw.TextStyle(
                      font: fontLight, fontSize: 14, color: _ink)),
                pw.SizedBox(height: 8),
              ],
              if (cities.isNotEmpty)
                pw.Text(cities.join('  ·  '),
                    style: pw.TextStyle(font: font, fontSize: 12, color: _muted)),

              pw.SizedBox(height: 64),
              pw.Container(height: 1, color: _border),
              pw.SizedBox(height: 24),

              // Stats row
              pw.Row(children: [
                _coverStat('${days.length}', 'DAYS', font, fontBold),
                pw.SizedBox(width: 40),
                _coverStat('$itemCount', 'ITEMS', font, fontBold),
                pw.SizedBox(width: 40),
                _coverStat(viewMode.label.toUpperCase(), 'ROLE VIEW', font, fontBold),
              ]),

              pw.Spacer(),

              pw.Text('Exported ${_dateShort.format(DateTime.now())}',
                  style: pw.TextStyle(font: font, fontSize: 10, color: _muted)),
              pw.SizedBox(height: 4),
              pw.Text('Internal use only — House of Dreammaker',
                  style: pw.TextStyle(font: fontBold, fontSize: 11, color: _ink)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _coverStat(
      String value, String label, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(value,
            style: pw.TextStyle(font: fontBold, fontSize: 22, color: _ink)),
        pw.SizedBox(height: 2),
        pw.Text(label,
            style: pw.TextStyle(
              font: font, fontSize: 8, color: _muted, letterSpacing: 1)),
      ],
    );
  }

  // ── Page header / footer ─────────────────────────────────────────────────────

  static pw.Widget _buildPageHeader(
    String tripName,
    RunSheetViewMode viewMode,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(children: [
              pw.Text('HOD TRAVEL',
                  style: pw.TextStyle(
                    font: fontBold, fontSize: 8, color: _gold,
                    letterSpacing: 2)),
              pw.Text('  ·  RUN SHEET  ·  ${viewMode.label.toUpperCase()}',
                  style: pw.TextStyle(
                    font: font, fontSize: 8, color: _muted, letterSpacing: 1)),
            ]),
            pw.Text(tripName,
                style: pw.TextStyle(font: font, fontSize: 8, color: _muted)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 0.5, color: _border),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static pw.Widget _buildPageFooter(pw.Context ctx, pw.Font font) {
    return pw.Column(
      children: [
        pw.Container(height: 0.5, color: _border),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Internal use only — House of Dreammaker',
                style: pw.TextStyle(font: font, fontSize: 8, color: _muted)),
            pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(font: font, fontSize: 8, color: _muted)),
          ],
        ),
      ],
    );
  }

  // ── Day section ──────────────────────────────────────────────────────────────

  static List<pw.Widget> _buildDaySection({
    required TripDay            day,
    required List<RunSheetItem> items,
    required pw.Font            font,
    required pw.Font            fontBold,
    required pw.Font            fontLight,
    required bool               showOps,
    required bool               showLogistics,
    required bool               showTransport,
    required bool               showGuide,
  }) {
    final dateStr = day.date != null ? _dateLong.format(day.date!) : '';

    return [
      pw.Text('DAY ${day.dayNumber}',
          style: pw.TextStyle(
            font: fontBold, fontSize: 9, color: _gold, letterSpacing: 2)),
      pw.SizedBox(height: 4),
      pw.Text(day.city,
          style: pw.TextStyle(font: fontBold, fontSize: 24, color: _ink)),
      if (dateStr.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        pw.Text(dateStr,
            style: pw.TextStyle(font: fontLight, fontSize: 11, color: _muted)),
      ],
      if (day.title != null) ...[
        pw.SizedBox(height: 4),
        pw.Text(day.title!,
            style: pw.TextStyle(font: font, fontSize: 11, color: _muted)),
      ],
      pw.SizedBox(height: 16),
      pw.Container(height: 1, color: _gold),
      pw.SizedBox(height: 20),

      for (final item in items) ...[
        _buildItemBlock(
          item:          item,
          font:          font,
          fontBold:      fontBold,
          showOps:       showOps,
          showLogistics: showLogistics,
          showTransport: showTransport,
          showGuide:     showGuide,
        ),
        pw.SizedBox(height: 24),
      ],
      pw.SizedBox(height: 40),
    ];
  }

  // ── Item card ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildItemBlock({
    required RunSheetItem item,
    required pw.Font      font,
    required pw.Font      fontBold,
    required bool         showOps,
    required bool         showLogistics,
    required bool         showTransport,
    required bool         showGuide,
  }) {
    final timeStr = _formatTimeRange(item.startTime, item.endTime)
        ?? _timeBlockLabel(item.timeBlock);

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color:        _white,
        border:       pw.Border.all(color: _border, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Type label + time
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(item.type.label.toUpperCase(),
                  style: pw.TextStyle(
                    font: fontBold, fontSize: 7.5, color: _gold,
                    letterSpacing: 1.2)),
              pw.Text(timeStr,
                  style: pw.TextStyle(font: font, fontSize: 9, color: _muted)),
            ],
          ),
          pw.SizedBox(height: 5),

          // Title
          pw.Text(item.title,
              style: pw.TextStyle(font: fontBold, fontSize: 12, color: _ink)),

          // Location
          if (item.location?.isNotEmpty == true) ...[
            pw.SizedBox(height: 4),
            pw.Text(item.location!,
                style: pw.TextStyle(font: font, fontSize: 9, color: _muted)),
          ],

          // Supplier
          if (item.supplierName?.isNotEmpty == true) ...[
            pw.SizedBox(height: 2),
            pw.Text(item.supplierName!,
                style: pw.TextStyle(font: font, fontSize: 9, color: _muted)),
          ],

          // Description
          if (item.description?.isNotEmpty == true) ...[
            pw.SizedBox(height: 6),
            pw.Text(item.description!,
                style: pw.TextStyle(
                  font: font, fontSize: 10, color: _ink, height: 1.5)),
          ],

          // Contacts + responsible
          if (_hasContactInfo(item)) ...[
            pw.SizedBox(height: 10),
            if (item.primaryContactName?.isNotEmpty == true)
              _contactRow('Contact', item.primaryContactName!,
                  item.primaryContactPhone, font, fontBold),
            if (item.backupContactName?.isNotEmpty == true)
              _contactRow('Backup', item.backupContactName!,
                  item.backupContactPhone, font, fontBold),
            if (item.responsibleName?.isNotEmpty == true)
              _contactRow('Responsible', item.responsibleName!,
                  null, font, fontBold),
          ],

          // Notes (role-scoped)
          if (_hasNotes(item, showOps, showLogistics, showTransport, showGuide)) ...[
            pw.SizedBox(height: 10),
            if (showOps       && item.opsNotes?.isNotEmpty       == true)
              _noteRow('OPS', item.opsNotes!, font, fontBold),
            if (showLogistics && item.logisticsNotes?.isNotEmpty == true)
              _noteRow('LOGISTICS', item.logisticsNotes!, font, fontBold),
            if (showTransport && item.transportNotes?.isNotEmpty == true)
              _noteRow('TRANSPORT', item.transportNotes!, font, fontBold),
            if (showGuide     && item.guideNotes?.isNotEmpty     == true)
              _noteRow('GUIDE', item.guideNotes!, font, fontBold),
          ],

          // Operational instructions
          if (item.hasInstructions) ...[
            pw.SizedBox(height: 10),
            if (item.operationalInstructions?.isNotEmpty == true)
              _instructionRow('OPERATIONAL', item.operationalInstructions!, font, fontBold),
            if (item.contingencyInstructions?.isNotEmpty == true) ...[
              pw.SizedBox(height: 8),
              _instructionRow('CONTINGENCY', item.contingencyInstructions!, font, fontBold),
            ],
            if (item.escalationInstructions?.isNotEmpty == true) ...[
              pw.SizedBox(height: 8),
              _instructionRow('ESCALATION', item.escalationInstructions!, font, fontBold),
            ],
          ],
        ],
      ),
    );
  }

  // ── Small builders ───────────────────────────────────────────────────────────

  static pw.Widget _contactRow(
    String label, String name, String? phone,
    pw.Font font, pw.Font fontBold,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text('$label:',
                style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: _muted)),
          ),
          pw.Text(name,
              style: pw.TextStyle(font: font, fontSize: 8.5, color: _ink)),
          if (phone?.isNotEmpty == true)
            pw.Text('  ·  $phone',
                style: pw.TextStyle(font: font, fontSize: 8.5, color: _muted)),
        ],
      ),
    );
  }

  static pw.Widget _noteRow(
    String label, String text, pw.Font font, pw.Font fontBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
              font: fontBold, fontSize: 7.5, color: _gold, letterSpacing: 1)),
        pw.SizedBox(height: 2),
        pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: 9, color: _ink, height: 1.5)),
      ],
    );
  }

  static pw.Widget _instructionRow(
    String label, String text, pw.Font font, pw.Font fontBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
              font: fontBold, fontSize: 7.5, color: _muted, letterSpacing: 1)),
        pw.SizedBox(height: 2),
        pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: 9, color: _ink, height: 1.5)),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static bool _hasContactInfo(RunSheetItem item) =>
      item.primaryContactName?.isNotEmpty == true ||
      item.backupContactName?.isNotEmpty  == true ||
      item.responsibleName?.isNotEmpty    == true;

  static bool _hasNotes(RunSheetItem item, bool showOps, bool showLogistics,
      bool showTransport, bool showGuide) =>
      (showOps       && item.opsNotes?.isNotEmpty       == true) ||
      (showLogistics && item.logisticsNotes?.isNotEmpty == true) ||
      (showTransport && item.transportNotes?.isNotEmpty == true) ||
      (showGuide     && item.guideNotes?.isNotEmpty     == true);

  static String? _formatTimeRange(TimeOfDay? start, TimeOfDay? end) {
    if (start == null) return null;
    final s = _fmtTime(start);
    return end == null ? s : '$s – ${_fmtTime(end)}';
  }

  static String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'am' : 'pm'}';
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
