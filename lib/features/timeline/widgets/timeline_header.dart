import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../services/timeline_mapper_service.dart';

/// Fixed-height date scale rendered at the top of the timeline canvas.
/// Two-row layout: month spans on top, day numbers on the bottom.
///
/// Scrolls horizontally in sync with the task-bar area (same ScrollController).
class TimelineHeader extends StatelessWidget {
  final TimelineDateRange range;

  const TimelineHeader({super.key, required this.range});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: range.totalWidth,
      height: kHeaderHeight,
      child: CustomPaint(
        painter: _HeaderPainter(range: range),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HeaderPainter
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderPainter extends CustomPainter {
  final TimelineDateRange range;

  _HeaderPainter({required this.range});

  static const double _monthRowH = 22.0;
  static const double _dayRowH   = 34.0;

  final _dayNumFmt  = DateFormat('d');
  final _dayAbbrFmt = DateFormat('E'); // Mon, Tue …

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawMonthRow(canvas, size);
    _drawDayRow(canvas, size);
    _drawTodayIndicator(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.surface;
    canvas.drawRect(Offset.zero & size, paint);

    // Bottom divider
    final div = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, size.height - 1), Offset(size.width, size.height - 1), div);
  }

  void _drawMonthRow(Canvas canvas, Size size) {
    // Group consecutive days by month, draw a label + right divider per span
    DateTime? currentMonth;
    double spanStart = 0;

    for (int i = 0; i <= range.totalDays; i++) {
      final isLast = i == range.totalDays;
      final date   = isLast ? null : range.start.add(Duration(days: i));
      final month  = date != null ? DateTime(date.year, date.month) : null;

      if (month != currentMonth || isLast) {
        if (currentMonth != null) {
          final spanEnd = i * kDayWidth;
          final spanW   = spanEnd - spanStart;

          // Month label — centred in span if wide enough
          if (spanW >= 40) {
            final label = DateFormat('MMM yyyy').format(currentMonth);
            _drawText(
              canvas,
              label,
              Offset(spanStart + spanW / 2, _monthRowH / 2),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            );
          }

          // Right divider
          if (!isLast) {
            canvas.drawLine(
              Offset(spanEnd, 0),
              Offset(spanEnd, _monthRowH),
              Paint()
                ..color = AppColors.border
                ..strokeWidth = 0.75,
            );
          }
        }
        currentMonth = month;
        spanStart    = i * kDayWidth;
      }
    }
  }

  void _drawDayRow(Canvas canvas, Size size) {
    final today = _dateOnly(DateTime.now());

    for (int i = 0; i < range.totalDays; i++) {
      final date    = range.start.add(Duration(days: i));
      final isToday = date == today;
      final isWeekend = date.weekday == DateTime.saturday ||
                        date.weekday == DateTime.sunday;
      final x = i * kDayWidth;

      // Weekend subtle background
      if (isWeekend) {
        canvas.drawRect(
          Rect.fromLTWH(x, _monthRowH, kDayWidth, _dayRowH),
          Paint()..color = const Color(0x06000000),
        );
      }

      // Today highlight background
      if (isToday) {
        final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 2, _monthRowH + 3, kDayWidth - 4, _dayRowH - 6),
          const Radius.circular(4),
        );
        canvas.drawRRect(rr, Paint()..color = AppColors.accentFaint);
      }

      // Vertical separator
      if (i > 0) {
        canvas.drawLine(
          Offset(x, _monthRowH),
          Offset(x, size.height),
          Paint()
            ..color = AppColors.border.withAlpha(120)
            ..strokeWidth = 0.5,
        );
      }

      // Day number
      if (kDayWidth >= 28) {
        final numStr  = _dayNumFmt.format(date);
        final abbr    = _dayAbbrFmt.format(date).substring(0, 1); // M T W…

        // Day-of-week letter
        _drawText(
          canvas,
          abbr,
          Offset(x + kDayWidth / 2, _monthRowH + 12),
          style: AppTextStyles.labelSmall.copyWith(
            color: isToday
                ? AppColors.accent
                : (isWeekend ? AppColors.textMuted : AppColors.textMuted),
            fontSize: 9,
          ),
        );

        // Day number
        _drawText(
          canvas,
          numStr,
          Offset(x + kDayWidth / 2, _monthRowH + 26),
          style: AppTextStyles.labelSmall.copyWith(
            color: isToday ? AppColors.accent : AppColors.textSecondary,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
        );
      }
    }
  }

  void _drawTodayIndicator(Canvas canvas, Size size) {
    final today  = _dateOnly(DateTime.now());
    if (!range.contains(today)) return;
    final x = range.offsetForDate(today) + kDayWidth / 2;

    // Small gold triangle at bottom of header pointing down
    final path = Path()
      ..moveTo(x - 4, size.height - 6)
      ..lineTo(x + 4, size.height - 6)
      ..lineTo(x, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.accent);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset centre, {
    required TextStyle style,
  }) {
    final span     = TextSpan(text: text, style: style);
    final painter  = TextPainter(
      text:            span,
      textDirection:   ui.TextDirection.ltr,
      textAlign:       TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _HeaderPainter old) =>
      old.range.start != range.start || old.range.end != range.end;
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid background painter — drawn under all task bars
// ─────────────────────────────────────────────────────────────────────────────

/// Paints alternating column backgrounds (weekends), today line,
/// and horizontal row separators onto the timeline canvas.
class TimelineGridPainter extends CustomPainter {
  final TimelineDateRange range;
  final double totalBodyHeight;
  final List<double> rowOffsets; // y offset of each row's top

  const TimelineGridPainter({
    required this.range,
    required this.totalBodyHeight,
    required this.rowOffsets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawColumnBackgrounds(canvas, size);
    _drawRowSeparators(canvas, size);
    _drawTodayLine(canvas, size);
  }

  void _drawColumnBackgrounds(Canvas canvas, Size size) {
    final weekendPaint = Paint()..color = const Color(0x04000000);
    final todayPaint   = Paint()..color = AppColors.accentFaint.withAlpha(80);
    final today        = _dateOnly(DateTime.now());

    for (int i = 0; i < range.totalDays; i++) {
      final date = range.start.add(Duration(days: i));
      final x    = i * kDayWidth;

      if (date == today) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, kDayWidth, size.height),
          todayPaint,
        );
      } else if (date.weekday == DateTime.saturday ||
                 date.weekday == DateTime.sunday) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, kDayWidth, size.height),
          weekendPaint,
        );
      }

      // Vertical day separator
      if (i > 0) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..color = AppColors.border.withAlpha(80)
            ..strokeWidth = 0.5,
        );
      }
    }
  }

  void _drawRowSeparators(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withAlpha(100)
      ..strokeWidth = 0.5;

    for (final y in rowOffsets) {
      if (y > 0) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  void _drawTodayLine(Canvas canvas, Size size) {
    final today = _dateOnly(DateTime.now());
    if (!range.contains(today)) return;
    final x = range.offsetForDate(today) + kDayWidth / 2;

    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = AppColors.accent.withAlpha(180)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant TimelineGridPainter old) =>
      old.range.start != range.start ||
      old.totalBodyHeight != totalBodyHeight;
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helper
// ─────────────────────────────────────────────────────────────────────────────

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
