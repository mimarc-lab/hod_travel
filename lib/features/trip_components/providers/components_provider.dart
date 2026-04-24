import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/approval_model.dart';
import '../../../data/models/cost_item_model.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/run_sheet_item.dart';
import '../../../data/models/trip_component_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/trip_component_repository.dart';
import '../widgets/component_linking_dialog.dart';

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

  Future<void> refresh() async {
    if (repository == null) return;
    try {
      final items = await repository!.fetchForTrip(trip.id);
      _components = items;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
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

  // ── Linking ────────────────────────────────────────────────────────────────

  /// Creates entries in Budget / Itinerary / Run Sheet based on [choice] and
  /// back-patches the component's link IDs.
  Future<void> linkComponent(TripComponent component, LinkingChoice choice) async {
    final repos = AppRepositories.instance;
    if (repos == null || teamId == null) return;

    String? newCostItemId;
    String? newItineraryItemId;
    String? newRunSheetItemId;
    String? dayId;

    // 1. Budget ──────────────────────────────────────────────────────────────
    if (choice.linkBudget) {
      try {
        final net = component.netCost ?? 0;
        final item = await repos.budget.create(
          CostItem(
            id:             '',
            tripId:         component.tripId,
            itemName:       component.title,
            category:       _toCostCategory(component.componentType),
            city:           component.locationName ?? '',
            date:           component.startDate,
            currency:       'USD',
            netCost:        net,
            markupType:     MarkupType.percentage,
            markupValue:    0,
            sellPrice:      net,
            paymentStatus:  PaymentStatus.pending,
            approvalStatus: ApprovalStatus.draft,
            supplierId:     component.supplierId,
            notes:          component.notesInternal,
          ),
          teamId!,
        );
        newCostItemId = item.id;
      } catch (e) {
        debugPrint('[linkComponent] budget: $e');
      }
    }

    // 2. Find / create trip day (needed for itinerary + run sheet) ────────────
    if (choice.linkItinerary || choice.linkRunSheet) {
      try {
        final days = await repos.itinerary.fetchDaysForTrip(component.tripId);
        TripDay? day;

        if (component.startDate != null) {
          final d = component.startDate!;
          for (final td in days) {
            if (td.date != null &&
                td.date!.year  == d.year &&
                td.date!.month == d.month &&
                td.date!.day   == d.day) {
              day = td;
              break;
            }
          }
          day ??= await repos.itinerary.createDay(
            TripDay(
              id:        '',
              tripId:    component.tripId,
              dayNumber: days.length + 1,
              date:      component.startDate,
              city:      component.locationName ?? '',
            ),
            teamId!,
          );
        } else if (days.isNotEmpty) {
          day = days.first;
        }

        dayId = day?.id;

        // 3. Itinerary item ───────────────────────────────────────────────────
        if (choice.linkItinerary && dayId != null && dayId.isNotEmpty) {
          final itinItem = await repos.itinerary.createItem(
            ItineraryItem(
              id:             '',
              tripDayId:      dayId,
              type:           _toItemType(component.componentType),
              title:          component.title,
              description:    component.notesClient,
              startTime:      _parseTimeStr(component.startTime),
              endTime:        _parseTimeStr(component.endTime),
              timeBlock:      TimeBlock.morning,
              location:       component.locationName,
              supplierId:     component.supplierId,
              supplierName:   component.supplierName,
              status:         ItemStatus.confirmed,
              approvalStatus: ApprovalStatus.approved,
              notes:          component.notesInternal,
            ),
            teamId!,
          );
          newItineraryItemId = itinItem.id;
        }
      } catch (e) {
        debugPrint('[linkComponent] itinerary: $e');
      }
    }

    // 4. Run Sheet ────────────────────────────────────────────────────────────
    if (choice.linkRunSheet && dayId != null && dayId.isNotEmpty) {
      try {
        newRunSheetItemId = await repos.runSheets.insert(
          RunSheetRow(
            id:              '',
            tripId:          component.tripId,
            dayId:           dayId,
            itineraryItemId: newItineraryItemId,
            opsNotes:        component.notesInternal,
            sortOrder:       0,
          ),
          teamId!,
        );
      } catch (e) {
        debugPrint('[linkComponent] run sheet: $e');
      }
    }

    // 5. Back-patch linked IDs onto the component ─────────────────────────────
    if (newCostItemId != null ||
        newItineraryItemId != null ||
        newRunSheetItemId != null) {
      await updateComponent(component.copyWith(
        costItemId:      newCostItemId      ?? component.costItemId,
        itineraryItemId: newItineraryItemId ?? component.itineraryItemId,
        runSheetItemId:  newRunSheetItemId  ?? component.runSheetItemId,
      ));
    }
  }

  // ── Type mappers ───────────────────────────────────────────────────────────

  static CostCategory _toCostCategory(ComponentType t) {
    switch (t) {
      case ComponentType.accommodation:      return CostCategory.accommodation;
      case ComponentType.dining:             return CostCategory.dining;
      case ComponentType.transport:          return CostCategory.transport;
      case ComponentType.experience:         return CostCategory.experience;
      case ComponentType.guide:              return CostCategory.guide;
      case ComponentType.specialArrangement: return CostCategory.other;
      case ComponentType.other:              return CostCategory.other;
    }
  }

  static ItemType _toItemType(ComponentType t) {
    switch (t) {
      case ComponentType.accommodation:      return ItemType.hotel;
      case ComponentType.dining:             return ItemType.dining;
      case ComponentType.transport:          return ItemType.transport;
      case ComponentType.guide:              return ItemType.experience;
      case ComponentType.experience:         return ItemType.experience;
      case ComponentType.specialArrangement: return ItemType.experience;
      case ComponentType.other:              return ItemType.note;
    }
  }

  static TimeOfDay? _parseTimeStr(String? t) {
    if (t == null) return null;
    final parts = t.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour:   int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
