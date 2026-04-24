import 'package:flutter/material.dart';
import '../models/task_assignment_model.dart';
import '../models/user_model.dart';
import '../models/trip_model.dart';
import '../models/task_model.dart';
import '../models/board_group_model.dart';
import '../models/task_comment_model.dart';

List<TaskAssignment> _lead(String taskId, AppUser user) => [
  TaskAssignment(
    id: '',
    taskId: taskId,
    user: user,
    role: 'lead',
    isPrimary: true,
    createdAt: DateTime(2026, 1, 1),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Mock Users
// ─────────────────────────────────────────────────────────────────────────────

final mockUsers = <AppUser>[
  AppUser(id: 'u1', name: 'Sophie Laurent',  initials: 'SL', avatarColor: avatarColorFor(0), role: 'Senior Travel Designer', appRole: AppRole.admin),
  AppUser(id: 'u2', name: 'James Okafor',    initials: 'JO', avatarColor: avatarColorFor(1), role: 'Trip Manager',           appRole: AppRole.tripLead),
  AppUser(id: 'u3', name: 'Mei Chen',        initials: 'MC', avatarColor: avatarColorFor(2), role: 'Logistics Coordinator',  appRole: AppRole.staff),
  AppUser(id: 'u4', name: 'Rafael Torres',   initials: 'RT', avatarColor: avatarColorFor(3), role: 'Client Relations',       appRole: AppRole.staff),
  AppUser(id: 'u5', name: 'Priya Sharma',    initials: 'PS', avatarColor: avatarColorFor(4), role: 'Finance Analyst',        appRole: AppRole.finance),
];

AppUser get currentUser => mockUsers[0];

// ─────────────────────────────────────────────────────────────────────────────
// Mock Trips
// ─────────────────────────────────────────────────────────────────────────────

final mockTrips = <Trip>[
  Trip(
    id: 't1',
    name: 'Amalfi & Sicily',
    clientName: 'The Hartwell Family',
    startDate: DateTime(2026, 6, 10),
    endDate: DateTime(2026, 6, 25),
    destinations: ['Naples', 'Positano', 'Palermo', 'Taormina'],
    guestCount: 6,
    tripLead: mockUsers[0],
    status: TripStatus.confirmed,
    notes: 'Anniversary celebration. Client prefers boutique properties only.',
  ),
  Trip(
    id: 't2',
    name: 'Japanese Highlands',
    clientName: 'Mr & Mrs Ashford',
    startDate: DateTime(2026, 9, 4),
    endDate: DateTime(2026, 9, 20),
    destinations: ['Tokyo', 'Kyoto', 'Hakone', 'Kanazawa'],
    guestCount: 2,
    tripLead: mockUsers[1],
    status: TripStatus.planning,
    notes: 'Preference for ryokans and off-the-beaten-path experiences.',
  ),
  Trip(
    id: 't3',
    name: 'Patagonia Expedition',
    clientName: 'The Reinhardt Group',
    startDate: DateTime(2026, 11, 15),
    endDate: DateTime(2026, 11, 30),
    destinations: ['Buenos Aires', 'El Calafate', 'Torres del Paine'],
    guestCount: 4,
    tripLead: mockUsers[2],
    status: TripStatus.planning,
  ),
  Trip(
    id: 't4',
    name: 'Maldives Escape',
    clientName: 'Mr Dominic Strauss',
    startDate: DateTime(2026, 4, 18),
    endDate: DateTime(2026, 4, 26),
    destinations: ['Malé', 'Baa Atoll'],
    guestCount: 2,
    tripLead: mockUsers[3],
    status: TripStatus.inProgress,
  ),
  Trip(
    id: 't5',
    name: 'Morocco & Sahara',
    clientName: 'The Okonkwo Family',
    startDate: DateTime(2026, 3, 5),
    endDate: DateTime(2026, 3, 16),
    destinations: ['Marrakech', 'Fès', 'Merzouga', 'Essaouira'],
    guestCount: 8,
    tripLead: mockUsers[0],
    status: TripStatus.completed,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Mock Board
// ─────────────────────────────────────────────────────────────────────────────

List<BoardGroup> mockBoardGroupsForTrip(String tripId) {
  return [
    BoardGroup(
      id: 'g1',
      name: 'Pre-Planning',
      accentColor: const Color(0xFF6366F1),
      tasks: [
        Task(id: 'tk1', boardGroupId: 'g1', name: 'Client intake call',   status: TaskStatus.confirmed,   assignments: _lead('tk1', mockUsers[0]), destination: 'N/A', dueDate: DateTime(2026, 3, 10), priority: TaskPriority.high,   costStatus: TaskCostStatus.pending),
        Task(id: 'tk2', boardGroupId: 'g1', name: 'Proposal document',    status: TaskStatus.confirmed,   assignments: _lead('tk2', mockUsers[0]), destination: 'N/A', dueDate: DateTime(2026, 3, 15), priority: TaskPriority.high,   costStatus: TaskCostStatus.pending, clientVisible: true),
        Task(id: 'tk3', boardGroupId: 'g1', name: 'Passport & visa check',status: TaskStatus.researching, assignments: _lead('tk3', mockUsers[3]), destination: 'N/A', dueDate: DateTime(2026, 4, 1),  priority: TaskPriority.medium, costStatus: TaskCostStatus.pending),
      ],
    ),
    BoardGroup(
      id: 'g2',
      name: 'Accommodation',
      accentColor: const Color(0xFF0EA5E9),
      tasks: [
        Task(id: 'tk4', boardGroupId: 'g2', name: 'Villa Rufolo — 3 nights',    status: TaskStatus.researching, assignments: _lead('tk4', mockUsers[0]), destination: 'Positano', travelDate: DateTime(2026, 6, 12), dueDate: DateTime(2026, 4, 20), supplierId: 'sup1', priority: TaskPriority.high, costStatus: TaskCostStatus.quoted, clientVisible: true),
        Task(id: 'tk5', boardGroupId: 'g2', name: 'Hotel San Domenico',          status: TaskStatus.notStarted,  assignments: _lead('tk5', mockUsers[1]), destination: 'Taormina',  travelDate: DateTime(2026, 6, 19), dueDate: DateTime(2026, 4, 25), supplierId: 'sup2', priority: TaskPriority.high, costStatus: TaskCostStatus.pending, clientVisible: true),
        Task(id: 'tk6', boardGroupId: 'g2', name: 'Palermo boutique hotel',      status: TaskStatus.notStarted,  assignments: _lead('tk6', mockUsers[1]), destination: 'Palermo',   travelDate: DateTime(2026, 6, 16), dueDate: DateTime(2026, 4, 25), priority: TaskPriority.medium, costStatus: TaskCostStatus.pending),
      ],
    ),
    BoardGroup(
      id: 'g3',
      name: 'Experiences',
      accentColor: const Color(0xFF10B981),
      tasks: [
        Task(id: 'tk7', boardGroupId: 'g3', name: 'Private boat tour — Amalfi coast',  status: TaskStatus.researching,   assignments: _lead('tk7', mockUsers[0]), destination: 'Positano', travelDate: DateTime(2026, 6, 13), dueDate: DateTime(2026, 5, 1),  supplierId: 'sup3', priority: TaskPriority.high, costStatus: TaskCostStatus.approved, clientVisible: true),
        Task(id: 'tk8', boardGroupId: 'g3', name: 'Cooking class — pasta & limoncello', status: TaskStatus.notStarted,   assignments: _lead('tk8', mockUsers[2]), destination: 'Naples',   travelDate: DateTime(2026, 6, 11), dueDate: DateTime(2026, 5, 5),  supplierId: 'sup4', priority: TaskPriority.low,  costStatus: TaskCostStatus.quoted, clientVisible: true),
        Task(id: 'tk9', boardGroupId: 'g3', name: 'Etna summit excursion',              status: TaskStatus.awaitingReply, assignments: _lead('tk9', mockUsers[2]), destination: 'Taormina', travelDate: DateTime(2026, 6, 21), dueDate: DateTime(2026, 5, 10), supplierId: 'sup5', priority: TaskPriority.medium, costStatus: TaskCostStatus.pending),
      ],
    ),
    BoardGroup(
      id: 'g4',
      name: 'Logistics',
      accentColor: const Color(0xFFF59E0B),
      tasks: [
        Task(id: 'tk10', boardGroupId: 'g4', name: 'International flights — LHR to NAP',   status: TaskStatus.awaitingReply, assignments: _lead('tk10', mockUsers[3]), destination: 'Naples',   travelDate: DateTime(2026, 6, 10), dueDate: DateTime(2026, 4, 15), priority: TaskPriority.high, costStatus: TaskCostStatus.quoted, clientVisible: true),
        Task(id: 'tk11', boardGroupId: 'g4', name: 'Private transfer — Naples to Positano', status: TaskStatus.notStarted,  assignments: _lead('tk11', mockUsers[2]), destination: 'Positano', travelDate: DateTime(2026, 6, 10), dueDate: DateTime(2026, 5, 15), supplierId: 'sup6', priority: TaskPriority.medium, costStatus: TaskCostStatus.pending),
        Task(id: 'tk12', boardGroupId: 'g4', name: 'Internal Sicily transfers',             status: TaskStatus.notStarted,  assignments: _lead('tk12', mockUsers[2]), destination: 'Sicily',   travelDate: DateTime(2026, 6, 16), dueDate: DateTime(2026, 5, 20), priority: TaskPriority.low,    costStatus: TaskCostStatus.pending),
      ],
    ),
    BoardGroup(
      id: 'g5',
      name: 'Finance',
      accentColor: const Color(0xFFEC4899),
      tasks: [
        Task(id: 'tk13', boardGroupId: 'g5', name: 'Budget summary sheet',     status: TaskStatus.researching, assignments: _lead('tk13', mockUsers[4]), dueDate: DateTime(2026, 4, 10), priority: TaskPriority.high,   costStatus: TaskCostStatus.quoted),
        Task(id: 'tk14', boardGroupId: 'g5', name: 'Deposit invoice to client',status: TaskStatus.notStarted,  assignments: _lead('tk14', mockUsers[4]), dueDate: DateTime(2026, 4, 20), priority: TaskPriority.high,   costStatus: TaskCostStatus.pending),
      ],
    ),
    BoardGroup(
      id: 'g6',
      name: 'Client Delivery',
      accentColor: const Color(0xFF8B5CF6),
      tasks: [
        Task(id: 'tk15', boardGroupId: 'g6', name: 'Digital itinerary — first draft', status: TaskStatus.notStarted, assignments: _lead('tk15', mockUsers[0]), dueDate: DateTime(2026, 5, 1),  priority: TaskPriority.high,   costStatus: TaskCostStatus.pending, clientVisible: true),
        Task(id: 'tk16', boardGroupId: 'g6', name: 'Client welcome pack',             status: TaskStatus.notStarted, assignments: _lead('tk16', mockUsers[3]), dueDate: DateTime(2026, 5, 25), priority: TaskPriority.medium, costStatus: TaskCostStatus.pending, clientVisible: true),
      ],
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard mock data
// ─────────────────────────────────────────────────────────────────────────────

List<Task> get mockMyTasks {
  return mockBoardGroupsForTrip('t1')
      .expand((g) => g.tasks)
      .where((t) => t.assignments.any((a) => a.user.id == currentUser.id))
      .toList();
}

List<Trip> get mockUpcomingTrips => mockTrips
    .where((t) =>
        t.status != TripStatus.completed &&
        t.startDate != null &&
        t.startDate!.isAfter(DateTime.now()))
    .toList()
  ..sort((a, b) => a.startDate!.compareTo(b.startDate!));

class ActivityItem {
  final AppUser user;
  final String action;
  final String subject;
  final DateTime time;

  const ActivityItem({
    required this.user,
    required this.action,
    required this.subject,
    required this.time,
  });
}

final mockActivityFeed = <ActivityItem>[
  ActivityItem(user: mockUsers[1], action: 'updated status on',  subject: 'Villa Rufolo — 3 nights',           time: DateTime.now().subtract(const Duration(minutes: 12))),
  ActivityItem(user: mockUsers[2], action: 'added a note to',    subject: 'Etna summit excursion',              time: DateTime.now().subtract(const Duration(minutes: 45))),
  ActivityItem(user: mockUsers[3], action: 'marked complete',    subject: 'Client intake call',                 time: DateTime.now().subtract(const Duration(hours: 2))),
  ActivityItem(user: mockUsers[4], action: 'uploaded file to',   subject: 'Budget summary sheet',               time: DateTime.now().subtract(const Duration(hours: 5))),
  ActivityItem(user: mockUsers[0], action: 'created task',       subject: 'Client welcome pack',                time: DateTime.now().subtract(const Duration(hours: 18))),
];

// ─────────────────────────────────────────────────────────────────────────────
// Mock Comments / Activity
// ─────────────────────────────────────────────────────────────────────────────

Map<String, List<TaskComment>> mockCommentsForTrip(String tripId) {
  final now = DateTime.now();
  return {
    'tk4': [
      TaskComment(id: 'a1', taskId: 'tk4', author: mockUsers[0], message: 'Task created',                createdAt: now.subtract(const Duration(days: 5)),  isActivity: true),
      TaskComment(id: 'c1', taskId: 'tk4', author: mockUsers[1], message: 'I\'ve reached out to Villa Rufolo. They\'re holding the dates but need a deposit confirmation by end of month.', createdAt: now.subtract(const Duration(days: 3))),
      TaskComment(id: 'a2', taskId: 'tk4', author: mockUsers[0], message: 'Status changed to "Researching"', createdAt: now.subtract(const Duration(days: 2)), isActivity: true),
      TaskComment(id: 'c2', taskId: 'tk4', author: mockUsers[0], message: 'Client has approved the property. Moving forward with the booking. Can you get the invoice raised?', createdAt: now.subtract(const Duration(hours: 6))),
    ],
    'tk7': [
      TaskComment(id: 'a3', taskId: 'tk7', author: mockUsers[0], message: 'Task created',           createdAt: now.subtract(const Duration(days: 4)),  isActivity: true),
      TaskComment(id: 'c3', taskId: 'tk7', author: mockUsers[0], message: 'Amalfi Charters confirmed availability. Private 8-hour cruise, capacity 8 guests. Champagne lunch included.', createdAt: now.subtract(const Duration(days: 2))),
      TaskComment(id: 'a4', taskId: 'tk7', author: mockUsers[2], message: 'Priority set to "High"', createdAt: now.subtract(const Duration(days: 1)),  isActivity: true),
    ],
    'tk9': [
      TaskComment(id: 'c4', taskId: 'tk9', author: mockUsers[2], message: 'Etna Guides are not responding to emails. May need an alternative provider. Checking with our Sicily DMC.', createdAt: now.subtract(const Duration(hours: 14))),
      TaskComment(id: 'a5', taskId: 'tk9', author: mockUsers[2], message: 'Status changed to "Awaiting Reply"', createdAt: now.subtract(const Duration(hours: 12)), isActivity: true),
    ],
    'tk10': [
      TaskComment(id: 'a6', taskId: 'tk10', author: mockUsers[3], message: 'Task created',                        createdAt: now.subtract(const Duration(days: 6)),  isActivity: true),
      TaskComment(id: 'c5', taskId: 'tk10', author: mockUsers[3], message: 'Sent flight options to client — LHR–NAP direct on June 10th. Awaiting approval on business class upgrade.', createdAt: now.subtract(const Duration(days: 1))),
      TaskComment(id: 'a7', taskId: 'tk10', author: mockUsers[3], message: 'Status changed to "Awaiting Reply"', createdAt: now.subtract(const Duration(hours: 23)), isActivity: true),
    ],
    'tk13': [
      TaskComment(id: 'c6', taskId: 'tk13', author: mockUsers[4], message: 'Initial budget draft is 85% complete. Still waiting on confirmed rates from Villa Rufolo and Amalfi Charters before finalising.', createdAt: now.subtract(const Duration(hours: 3))),
    ],
  };
}
