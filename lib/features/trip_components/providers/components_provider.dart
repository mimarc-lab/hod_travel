import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/models/trip_component_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/trip_component_repository.dart';

class ComponentsProvider extends ChangeNotifier {
  final Trip trip;
  final TripComponentRepository? repository;
  final String? teamId;

  List<TripComponent> _components = [];
  ComponentType? _filterType;
  ComponentStatus? _filterStatus;
  bool _loading = false;
  String? _error;
  StreamSubscription<List<TripComponent>>? _sub;

  ComponentsProvider({
    required this.trip,
    this.repository,
    this.teamId,
  }) {
    _init();
  }

  List<TripComponent> get allComponents => _components;
  ComponentType?   get filterType   => _filterType;
  ComponentStatus? get filterStatus => _filterStatus;
  bool             get loading      => _loading;
  String?          get error        => _error;

  List<TripComponent> get filtered {
    var list = _components;
    if (_filterType   != null) list = list.where((c) => c.componentType == _filterType).toList();
    if (_filterStatus != null) list = list.where((c) => c.status == _filterStatus).toList();
    list.sort((a, b) {
      final dateA = a.startDate;
      final dateB = b.startDate;
      if (dateA == null && dateB == null) return a.title.compareTo(b.title);
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    });
    return list;
  }

  Map<ComponentType, int> get countsByType {
    final map = <ComponentType, int>{};
    for (final c in _components) {
      map[c.componentType] = (map[c.componentType] ?? 0) + 1;
    }
    return map;
  }

  void setFilterType(ComponentType? t) {
    _filterType = t;
    notifyListeners();
  }

  void setFilterStatus(ComponentStatus? s) {
    _filterStatus = s;
    notifyListeners();
  }

  void _init() {
    if (repository == null) return;
    _loading = true;
    _sub = repository!.watchForTrip(trip.id).listen(
      (items) {
        _components = items;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<TripComponent?> addComponent(TripComponent component) async {
    if (repository == null || teamId == null) return null;
    try {
      final created = await repository!.create(component, teamId!);
      _components = [..._components, created];
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<TripComponent?> updateComponent(TripComponent component) async {
    if (repository == null) return null;
    final prev = _components.toList();
    _components = [
      for (final c in _components) c.id == component.id ? component : c,
    ];
    notifyListeners();
    try {
      final updated = await repository!.update(component);
      _components = [
        for (final c in _components) c.id == updated.id ? updated : c,
      ];
      notifyListeners();
      return updated;
    } catch (e) {
      _components = prev;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteComponent(String id) async {
    if (repository == null) return;
    final prev = _components.toList();
    _components = _components.where((c) => c.id != id).toList();
    notifyListeners();
    try {
      await repository!.delete(id);
    } catch (e) {
      _components = prev;
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
