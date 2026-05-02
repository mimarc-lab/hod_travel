import 'package:flutter/material.dart' show TimeOfDay, DayPeriod;
import 'package:intl/intl.dart';
import '../../../data/models/trip_component_model.dart';

typedef BookingRow = ({String key, String value});

/// Returns a flat list of label/value rows for a TripComponent's booking
/// details, ready to render in both the card view and PDF export.
List<BookingRow> buildComponentBookingRows(TripComponent c) {
  final rows = <BookingRow>[];
  final d = c.detailsJson;

  void add(String label, String? value) {
    if (value != null && value.trim().isNotEmpty) {
      rows.add((key: label, value: value.trim()));
    }
  }

  switch (c.componentType) {
    case ComponentType.accommodation:
      if (c.startDate != null) {
        final t = _fmtTimeStr(c.startTime);
        add('Check-in', t != null
            ? '${fmtComponentDate(c.startDate!)}  ·  $t'
            : fmtComponentDate(c.startDate!));
      }
      if (c.endDate != null) {
        final t = _fmtTimeStr(c.endTime);
        add('Check-out', t != null
            ? '${fmtComponentDate(c.endDate!)}  ·  $t'
            : fmtComponentDate(c.endDate!));
      }
      add('Booking Reference',    c.supplierBookingReference);
      add('Confirmation Number',  c.confirmationNumber);
      add('Room / Villa Type',    d['room_type']           as String?);
      add('Room Number',          d['room_number']         as String?);
      add('Bed Configuration',    d['bed_configuration']   as String?);
      if (d['breakfast_included'] == true) add('Breakfast', 'Included');
      add('Check-in Instructions', d['check_in_instructions'] as String?);

    case ComponentType.dining:
      if (c.startDate != null) {
        final t = _fmtTimeStr(c.startTime);
        add('Date & Time', t != null
            ? '${fmtComponentDate(c.startDate!)}  ·  $t'
            : fmtComponentDate(c.startDate!));
      }
      add('Reservation Name',  d['reservation_name'] as String?);
      add('Meal Type',         d['meal_type']        as String?);
      add('Dress Code',        d['dress_code']       as String?);
      add('Table Preference',  d['table_preference'] as String?);
      add('Dietary Notes',     d['dietary_notes']    as String?);
      add('Booking Reference', c.supplierBookingReference);

    case ComponentType.transport:
      if (c.startDate != null) add('Date', fmtComponentDate(c.startDate!));
      final startFmt = _fmtTimeStr(c.startTime);
      if (startFmt != null) {
        final endFmt = _fmtTimeStr(c.endTime);
        add('Departure / Arrival',
            endFmt != null ? '$startFmt – $endFmt' : startFmt);
      }
      add('Transport Type',      d['transport_type']      as String?);
      add('Carrier',             d['carrier']             as String?);
      add('Flight / Train No.',  d['flight_number']       as String?);
      add('Class of Service',    d['class_of_service']    as String?);
      add('Departure Terminal',  d['departure_terminal']  as String?);
      add('Arrival Location',    d['arrival_location']    as String?);
      add('Seat Number',         d['seat_number']         as String?);
      add('Driver',              d['driver_name']         as String?);
      add('Driver Phone',        d['driver_phone']        as String?);
      add('Vehicle',             d['vehicle_description'] as String?);
      add('Booking Reference',   c.supplierBookingReference);
      add('Confirmation Number', c.confirmationNumber);

    case ComponentType.experience:
      if (c.startDate != null) {
        final t = _fmtTimeStr(c.startTime);
        add('Date & Time', t != null
            ? '${fmtComponentDate(c.startDate!)}  ·  $t'
            : fmtComponentDate(c.startDate!));
      }
      final dur = d['duration_hours'];
      if (dur != null) add('Duration', '$dur hrs');
      final grp = d['group_size'];
      if (grp != null) add('Group Size', '$grp pax');
      add('Difficulty Level',   d['difficulty_level']   as String?);
      add('Equipment Provided', d['equipment_provided'] as String?);
      add('What to Bring',      d['what_to_bring']      as String?);
      add('Booking Reference',  c.supplierBookingReference);

    case ComponentType.guide:
      if (c.startDate != null) add('Date', fmtComponentDate(c.startDate!));
      add('Speciality',     d['guide_speciality'] as String?);
      add('Languages',      d['languages']        as String?);
      add('License / Cert', d['guide_license']    as String?);
      if (d['vehicle_included'] == true) add('Vehicle', 'Included');

    case ComponentType.specialArrangement:
      add('Arrangement Type', d['arrangement_type'] as String?);
      add('Details',          d['special_notes']    as String?);

    case ComponentType.other:
      break;
  }

  if (c.primaryContactName?.isNotEmpty == true) {
    final phone = c.primaryContactPhone?.isNotEmpty == true
        ? '  ·  ${c.primaryContactPhone}'
        : '';
    add('Primary Contact', '${c.primaryContactName}$phone');
  }
  add('Internal Notes', c.notesInternal);

  return rows;
}

String fmtComponentDate(DateTime d) => DateFormat('EEE, d MMM yyyy').format(d);

/// Converts a stored "HH:MM" or "HH:MM:SS" string to "h:mm am/pm".
/// Returns null when the input is null, empty, or unparseable.
String? _fmtTimeStr(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  final tod    = TimeOfDay(hour: h, minute: m);
  final hh     = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
  final mm     = m.toString().padLeft(2, '0');
  final period = tod.period == DayPeriod.am ? 'am' : 'pm';
  return '$hh:$mm $period';
}
