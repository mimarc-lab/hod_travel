import 'package:flutter/material.dart';

/// Border-radius constants for the adaptive table system.
abstract class AdaptiveRadius {
  static const double row         = 12.0;
  static const double card        = 16.0;
  static const double chip        = 20.0;  // pill chips (status, priority)
  static const double chipSmall   = 6.0;   // compact square chips
  static const double groupHeader = 10.0;
  static const double expandSection = 12.0;

  static BorderRadius get rowBorder         => BorderRadius.circular(row);
  static BorderRadius get cardBorder        => BorderRadius.circular(card);
  static BorderRadius get chipBorder        => BorderRadius.circular(chip);
  static BorderRadius get chipSmallBorder   => BorderRadius.circular(chipSmall);
  static BorderRadius get groupHeaderBorder => BorderRadius.circular(groupHeader);
}
