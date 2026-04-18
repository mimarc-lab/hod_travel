import 'package:flutter/material.dart' show DayPeriod, TimeOfDay;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/models/itinerary_models.dart';
import '../../../data/models/trip_model.dart';

/// Generates and triggers a print/save dialog for a client-facing itinerary PDF.
///
/// Uses the `pdf` package for layout and `printing` for the platform dialog.
/// On Flutter Web this opens the browser print dialog.
/// On iOS/Android it opens the system share/print sheet.
class PdfExportService {
  // ── Colors ──────────────────────────────────────────────────────────────────

  static const _gold     = PdfColor.fromInt(0xFFC9A96E);
  static const _ink      = PdfColor.fromInt(0xFF111318);
  static const _muted    = PdfColor.fromInt(0xFF9CA3AF);
  static const _border   = PdfColor.fromInt(0xFFE8E7E5);
  static const _bg       = PdfColor.fromInt(0xFFF8F7F5);
  static const _white    = PdfColors.white;

  // ── Entry point ─────────────────────────────────────────────────────────────

  /// Builds the PDF and opens the print dialog.
  static Future<void> export({
    required Trip trip,
    required List<TripDay> days,
    required Map<String, List<ItineraryItem>> itemsByDayId,
  }) async {
    final doc = pw.Document(
      title: trip.name,
      author: 'HOD Travel',
      subject: 'Client Itinerary',
    );

    // Load a font
    final font       = await PdfGoogleFonts.interRegular();
    final fontBold   = await PdfGoogleFonts.interSemiBold();
    final fontLight  = await PdfGoogleFonts.interLight();

    final baseTheme = pw.ThemeData(
      defaultTextStyle: pw.TextStyle(font: font, fontSize: 10, color: _ink),
    );

    // ── Cover page ───────────────────────────────────────────────────────────
    doc.addPage(
      pw.Page(
        theme: baseTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (ctx) => _buildCoverPage(trip, fontBold, fontLight, font),
      ),
    );

    // ── Day pages ────────────────────────────────────────────────────────────
    final sortedDays = List<TripDay>.from(days)
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

    for (final day in sortedDays) {
      final items = (itemsByDayId[day.id] ?? [])
          .where(ClientVisibilityFilter.isVisible)
          .toList();

      doc.addPage(
        pw.MultiPage(
          theme: baseTheme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 48),
          header: (ctx) => _buildPageHeader(trip, font, fontBold),
          footer: (ctx) => _buildPageFooter(ctx, trip, font),
          build: (ctx) => _buildDayPage(day, items, font, fontBold, fontLight),
        ),
      );
    }

    // Trigger print / save dialog
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: '${trip.name} — Itinerary',
    );
  }

  // ── Cover page ───────────────────────────────────────────────────────────────

  static pw.Widget _buildCoverPage(
    Trip trip,
    pw.Font fontBold,
    pw.Font fontLight,
    pw.Font font,
  ) {
    final dateStr = trip.startDate != null && trip.endDate != null
        ? '${DateFormat('d MMMM').format(trip.startDate!)} – ${DateFormat('d MMMM yyyy').format(trip.endDate!)}'
        : '';
    final nights = trip.startDate != null && trip.endDate != null
        ? trip.endDate!.difference(trip.startDate!).inDays
        : 0;

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

              pw.Text('PRIVATE JOURNEY',
                  style: pw.TextStyle(
                    font: font, fontSize: 11, color: _muted,
                    letterSpacing: 2)),
              pw.SizedBox(height: 12),
              pw.Text(trip.name,
                  style: pw.TextStyle(
                    font: fontBold, fontSize: 36, color: _ink,
                    height: 1.2)),
              pw.SizedBox(height: 24),

              if (dateStr.isNotEmpty) ...[
                pw.Text('$dateStr  ·  $nights nights',
                    style: pw.TextStyle(font: fontLight, fontSize: 14, color: _ink)),
                pw.SizedBox(height: 8),
              ],
              pw.Text(trip.destinations.join('  ·  '),
                  style: pw.TextStyle(font: font, fontSize: 12, color: _muted)),

              pw.SizedBox(height: 64),
              pw.Container(height: 1, color: _border),
              pw.SizedBox(height: 24),

              pw.Row(children: [
                _coverStat('${trip.guestCount}', 'GUESTS', font, fontBold),
                pw.SizedBox(width: 40),
                if (nights > 0) ...[
                  _coverStat('$nights', 'NIGHTS', font, fontBold),
                  pw.SizedBox(width: 40),
                ],
                _coverStat('${trip.destinations.length}', 'DESTINATIONS', font, fontBold),
              ]),

              pw.Spacer(),

              pw.Text('Prepared exclusively for',
                  style: pw.TextStyle(font: font, fontSize: 10, color: _muted)),
              pw.SizedBox(height: 4),
              pw.Text(trip.clientName,
                  style: pw.TextStyle(font: fontBold, fontSize: 16, color: _ink)),
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
        pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 24, color: _ink)),
        pw.SizedBox(height: 2),
        pw.Text(label,
            style: pw.TextStyle(font: font, fontSize: 8, color: _muted, letterSpacing: 1)),
      ],
    );
  }

  // ── Page header / footer ──────────────────────────────────────────────────────

  static pw.Widget _buildPageHeader(Trip trip, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('HOD TRAVEL',
                style: pw.TextStyle(
                    font: fontBold, fontSize: 8, color: _gold, letterSpacing: 2)),
            pw.Text(trip.name,
                style: pw.TextStyle(font: font, fontSize: 8, color: _muted)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 0.5, color: _border),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static pw.Widget _buildPageFooter(
      pw.Context ctx, Trip trip, pw.Font font) {
    return pw.Column(
      children: [
        pw.Container(height: 0.5, color: _border),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Prepared exclusively for ${trip.clientName}',
                style: pw.TextStyle(font: font, fontSize: 8, color: _muted)),
            pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(font: font, fontSize: 8, color: _muted)),
          ],
        ),
      ],
    );
  }

  // ── Day page ─────────────────────────────────────────────────────────────────

  static List<pw.Widget> _buildDayPage(
    TripDay day,
    List<ItineraryItem> items,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontLight,
  ) {
    final dateStr = day.date != null
        ? DateFormat('EEEE, d MMMM yyyy').format(day.date!)
        : '';

    return [
      // Day header
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
      if (day.title != null || day.label != null) ...[
        pw.SizedBox(height: 4),
        pw.Text(day.title ?? day.label ?? '',
            style: pw.TextStyle(font: font, fontSize: 11, color: _muted)),
      ],
      pw.SizedBox(height: 16),
      pw.Container(height: 1, color: _gold),
      pw.SizedBox(height: 20),

      // Items
      if (items.isEmpty)
        pw.Text('Details to be confirmed.',
            style: pw.TextStyle(font: font, fontSize: 10, color: _muted))
      else
        for (final item in items) ...[
          _buildItemBlock(item, font, fontBold),
          pw.SizedBox(height: 12),
        ],
    ];
  }

  static pw.Widget _buildItemBlock(
      ItineraryItem item, pw.Font font, pw.Font fontBold) {
    final timeStr = _formatTimeRange(item.startTime, item.endTime);
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _white,
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(item.type.label.toUpperCase(),
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 7.5, color: _gold,
                      letterSpacing: 1.2)),
              if (timeStr != null)
                pw.Text(timeStr,
                    style: pw.TextStyle(font: font, fontSize: 9, color: _muted)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(item.title,
              style: pw.TextStyle(font: fontBold, fontSize: 12, color: _ink)),
          if (item.description != null && item.description!.isNotEmpty) ...[
            pw.SizedBox(height: 5),
            pw.Text(item.description!,
                style: pw.TextStyle(font: font, fontSize: 10, color: _ink, height: 1.5)),
          ],
          if (item.location != null && item.location!.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(item.location!,
                style: pw.TextStyle(font: font, fontSize: 9, color: _muted)),
          ],
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String? _formatTimeRange(TimeOfDay? start, TimeOfDay? end) {
    if (start == null) return null;
    final s = _fmtTime(start);
    if (end == null) return s;
    return '$s – ${_fmtTime(end)}';
  }

  static String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'am' : 'pm';
    return '$h:$m $period';
  }
}

// ── Visibility filter (shared with screen) ────────────────────────────────────

/// Determines which itinerary items are safe to show to clients.
/// Add `is_client_visible` DB column in a future migration to give
/// operations staff per-item control.
class ClientVisibilityFilter {
  static bool isVisible(ItineraryItem item) {
    // Note-type items shown only when they have a client description
    if (item.type == ItemType.note) {
      return item.description != null && item.description!.isNotEmpty;
    }
    return true;
  }

  /// Returns the item with internal-only fields stripped.
  static ItineraryItem sanitize(ItineraryItem item) =>
      item.copyWith(clearNotes: true);
}
