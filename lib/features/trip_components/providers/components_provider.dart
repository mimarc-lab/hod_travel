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
            city:           component.city ?? '',
            date:           component.startDate,
            currency:       'USD',
            netCost:        net,
            depositPaid:    component.depositPaid ?? 0,
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
              city:      component.city ?? '',
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
              location:       component.address ?? component.locationName,
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

  // ── Sync linked records ────────────────────────────────────────────────────

  /// Pushes updated component fields to any already-linked budget / itinerary
  /// records. Called after every component edit so the linked records stay
  /// in sync without the user having to re-link.
  ///
  /// Returns the updated [ItineraryItem] if one was synced, otherwise null.
  Future<ItineraryItem?> syncLinkedRecords(TripComponent component) async {
    final repos = AppRepositories.instance;
    if (repos == null) return null;

    // 1. Budget item ──────────────────────────────────────────────────────────
    if (component.costItemId != null) {
      try {
        final existing = await repos.budget.fetchById(component.costItemId!);
        if (existing != null) {
          final net  = component.netCost ?? existing.netCost;
          final sell = CostItem.deriveSellPrice(
              net, existing.markupType, existing.markupValue);
          await repos.budget.update(existing.copyWith(
            itemName:    component.title,
            netCost:     net,
            sellPrice:   sell,
            depositPaid: component.depositPaid ?? existing.depositPaid,
            city:        component.city?.isNotEmpty == true
                ? component.city!
                : existing.city,
            date:           component.startDate,
            clearDate:      component.startDate == null,
            supplierId:     component.supplierId,
            clearSupplierId: component.supplierId == null,
            notes:      component.notesInternal,
            clearNotes: component.notesInternal == null,
          ));
        }
      } catch (e) {
        debugPrint('[syncLinkedRecords] budget: $e');
      }
    }

    // 2. Itinerary item ───────────────────────────────────────────────────────
    if (component.itineraryItemId != null) {
      try {
        final existing =
            await repos.itinerary.fetchItemById(component.itineraryItemId!);
        if (existing != null) {
          final st = _parseTimeStr(component.startTime);
          final et = _parseTimeStr(component.endTime);
          final updated = await repos.itinerary.updateItem(existing.copyWith(
            title:        component.title,
            description:  component.notesClient,
            clearDescription: component.notesClient == null,
            startTime:    st,
            clearStartTime: st == null,
            endTime:      et,
            clearEndTime:   et == null,
            location:     component.address ?? component.locationName,
            clearLocation: component.address == null && component.locationName == null,
            supplierId:   component.supplierId,
            clearSupplierId: component.supplierId == null,
            supplierName: component.supplierName,
            clearSupplierName: component.supplierName == null,
          ));
          return updated;
        }
      } catch (e) {
        debugPrint('[syncLinkedRecords] itinerary: $e');
      }
    }

    return null;
  }

  // ── Itinerary recalculation ────────────────────────────────────────────────

  /// Ensures every component-linked itinerary item sits under the correct
  /// TripDay (matched by startDate) and that all days are numbered in
  /// chronological date order.
  ///
  /// Returns true if any day was moved or renumbered, so callers can decide
  /// whether to show a reorder notification.
  Future<bool> recalculateItineraryFromComponents(String tripId) async {
    final repos = AppRepositories.instance;
    if (repos == null || teamId == null) return false;

    try {
      // Fetch all components; phase 1 only applies to those with a linked
      // itinerary item AND a start date, but phase 2 always runs.
      final all = await repos.components.fetchForTrip(tripId);
      final linked = all
          .where((c) => c.itineraryItemId != null && c.startDate != null)
          .toList();

      // Fetch days and all items in two queries.
      var days = await repos.itinerary.fetchDaysForTrip(tripId);
      if (days.isEmpty) return false;

      final itemsByDay = await repos.itinerary.fetchItemsForTrip(tripId);
      final itemMap = <String, ItineraryItem>{
        for (final list in itemsByDay.values)
          for (final item in list) item.id: item,
      };

      bool reordered = false;

      // ── Phase 1: move items to the correct day ─────────────────────────────
      for (final c in linked) {
        final target = DateTime(
            c.startDate!.year, c.startDate!.month, c.startDate!.day);

        // Find or create the day for this date.
        TripDay? correctDay;
        for (final d in days) {
          if (d.date != null &&
              d.date!.year  == target.year &&
              d.date!.month == target.month &&
              d.date!.day   == target.day) {
            correctDay = d;
            break;
          }
        }

        if (correctDay == null) {
          final city = linked
              .where((x) =>
                  x.startDate!.year  == target.year &&
                  x.startDate!.month == target.month &&
                  x.startDate!.day   == target.day &&
                  x.city?.isNotEmpty == true)
              .map((x) => x.city!)
              .firstOrNull ?? c.city ?? '';
          correctDay = await repos.itinerary.createDay(
            TripDay(
              id:        '',
              tripId:    tripId,
              dayNumber: days.length + 1, // temporary; fixed in phase 2
              date:      target,
              city:      city,
            ),
            teamId!,
          );
          days = [...days, correctDay];
          reordered = true;
        }

        final item = itemMap[c.itineraryItemId!];
        if (item != null && item.tripDayId != correctDay.id) {
          await repos.itinerary.updateItem(
              item.copyWith(tripDayId: correctDay.id));
          reordered = true;
        }
      }

      // ── Phase 2: renumber days in date order ───────────────────────────────
      days = await repos.itinerary.fetchDaysForTrip(tripId);
      final withDate = [...days.where((d) => d.date != null)]
        ..sort((a, b) => a.date!.compareTo(b.date!));
      final noDate = days.where((d) => d.date == null).toList();
      final ordered = [...withDate, ...noDate];

      // Check if any renumbering is actually needed before touching the DB.
      bool needsRenumber = false;
      for (int i = 0; i < ordered.length; i++) {
        if (ordered[i].dayNumber != i + 1) { needsRenumber = true; break; }
      }

      if (needsRenumber) {
        reordered = true;
        // Pass 1: move to large temporary numbers (10001+) to avoid the
        // UNIQUE(trip_id, day_number) constraint during circular renaming.
        for (int i = 0; i < ordered.length; i++) {
          await repos.itinerary.upsertDay(
              ordered[i].copyWith(dayNumber: i + 1 + 10000), teamId!);
        }
        // Pass 2: set final correct numbers.
        for (int i = 0; i < ordered.length; i++) {
          await repos.itinerary.upsertDay(
              ordered[i].copyWith(dayNumber: i + 1), teamId!);
        }
      }

      return reordered;
    } catch (e) {
      debugPrint('[recalculateItinerary] $e');
      return false;
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
