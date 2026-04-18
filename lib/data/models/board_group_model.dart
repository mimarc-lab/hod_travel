import 'package:flutter/material.dart';
import 'task_model.dart';

class BoardGroup {
  final String id;
  final String name;
  final Color accentColor;
  final List<Task> tasks;

  const BoardGroup({
    required this.id,
    required this.name,
    required this.accentColor,
    required this.tasks,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Default board group configuration (used when trip has no groups yet)
// ─────────────────────────────────────────────────────────────────────────────

const defaultBoardGroupNames = [
  'Pre-Planning',
  'Accommodation',
  'Experiences',
  'Logistics',
  'Finance',
  'Client Delivery',
];

const defaultBoardGroupColors = [
  Color(0xFF9E9E9E),
  Color(0xFF7C6FAB),
  Color(0xFFC9A96E),
  Color(0xFF4A90A4),
  Color(0xFF5A9E6F),
  Color(0xFF4A90A4),
];
