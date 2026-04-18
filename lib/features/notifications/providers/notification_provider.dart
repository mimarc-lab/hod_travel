import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notification_repository.dart';

/// Realtime strategy: subscribes to [NotificationRepository.watchForUser]
/// which fires on every INSERT for the current user. The subscription seeds
/// the initial list, so no separate [reload] call is needed at startup.
class NotificationProvider extends ChangeNotifier {
  final NotificationRepository? _repo;
  final String? _currentUserId;

  List<AppNotification> _items = const [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<AppNotification>>? _sub;

  NotificationProvider({
    NotificationRepository? repository,
    String? currentUserId,
  })  : _repo = repository,
        _currentUserId = currentUserId {
    if (_repo != null && currentUserId != null) _subscribe();
  }

  String? get currentUserId              => _currentUserId;
  List<AppNotification> get all          => List.unmodifiable(_items);
  List<AppNotification> get unread       => _items.where((n) => !n.isRead).toList();
  int get unreadCount                    => unread.length;
  bool get isLoading                     => _isLoading;
  String? get error                      => _error;

  // ── Realtime subscription ──────────────────────────────────────────────────

  void _subscribe() {
    final userId = _currentUserId;
    if (_repo == null || userId == null) return;
    _isLoading = true;
    notifyListeners();
    _sub?.cancel();
    _sub = _repo.watchForUser(userId).listen(
      (items) {
        _items = items;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (_) {
        _error = 'Could not load notifications.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> reload() async {
    _sub?.cancel();
    _subscribe();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> markRead(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx == -1 || _items[idx].isRead) return;
    // Optimistic update — subscription will confirm
    _items = List.of(_items)..[idx] = _items[idx].copyWith(isRead: true);
    notifyListeners();
    await _repo?.markRead(id);
  }

  Future<void> markAllRead() async {
    bool changed = false;
    final updated = List.of(_items);
    for (int i = 0; i < updated.length; i++) {
      if (!updated[i].isRead) {
        updated[i] = updated[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      _items = updated;
      notifyListeners();
      final userId = _currentUserId;
      if (userId != null) await _repo?.markAllRead(userId);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
