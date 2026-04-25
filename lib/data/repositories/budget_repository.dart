import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/approval_model.dart';
import '../models/cost_item_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class BudgetRepository {
  Future<List<CostItem>> fetchForTrip(String tripId);
  Future<List<CostItem>> fetchAll(String teamId);
  Future<CostItem> create(CostItem item, String teamId);
  Future<CostItem> update(CostItem item);
  Future<void> delete(String id);

  /// Realtime stream — emits refreshed items for a single trip.
  Stream<List<CostItem>> watchForTrip(String tripId);

  /// Realtime stream — emits refreshed items across all trips for the team.
  Stream<List<CostItem>> watchAll(String teamId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Mappers
// ─────────────────────────────────────────────────────────────────────────────

CostItem _fromRow(Map<String, dynamic> r) {
  final supplierMap = r['suppliers'] as Map<String, dynamic>?;
  return CostItem(
    id:             r['id'] as String,
    tripId:         r['trip_id'] as String,
    taskId:         r['task_id'] as String?,
    itineraryItemId: r['itinerary_item_id'] as String?,
    supplierId:     r['supplier_id'] as String?,
    supplierName:   supplierMap?['name'] as String?,
    itemName:       r['item_name'] as String,
    category:       costCategoryFromDb(r['category'] as String? ?? 'other'),
    city:           r['city'] as String? ?? '',
    date: r['service_date'] != null
        ? DateTime.parse(r['service_date'] as String)
        : null,
    currency:       r['currency'] as String? ?? 'USD',
    netCost:        (r['net_cost'] as num? ?? 0).toDouble(),
    depositPaid:    (r['deposit_paid'] as num? ?? 0).toDouble(),
    markupType:     r['markup_type'] == 'fixed'
        ? MarkupType.fixed
        : MarkupType.percentage,
    markupValue:    (r['markup_value'] as num? ?? 0).toDouble(),
    sellPrice:      (r['sell_price'] as num? ?? 0).toDouble(),
    paymentStatus:  paymentStatusFromDb(r['payment_status'] as String? ?? 'pending'),
    approvalStatus: approvalStatusFromDb(r['approval_status'] as String? ?? 'draft'),
    paymentDueDate: r['payment_due_date'] != null
        ? DateTime.parse(r['payment_due_date'] as String)
        : null,
    notes: r['notes'] as String?,
  );
}

Map<String, dynamic> _toRow(CostItem i, {String? teamId}) => {
  'team_id':           ?teamId,
  'trip_id':           i.tripId,
  'task_id':           i.taskId,
  'itinerary_item_id': i.itineraryItemId,
  'supplier_id':       i.supplierId,
  'item_name':         i.itemName,
  'category':          i.category.dbValue,
  'city':              i.city,
  'service_date':      i.date?.toIso8601String().substring(0, 10),
  'currency':          i.currency,
  'net_cost':          i.netCost,
  'deposit_paid':      i.depositPaid,
  'markup_type':       i.markupType == MarkupType.fixed ? 'fixed' : 'percentage',
  'markup_value':      i.markupValue,
  'sell_price':        i.sellPrice,
  'payment_status':    i.paymentStatus.dbValue,
  'approval_status':   i.approvalStatus.dbValue,
  'payment_due_date':  i.paymentDueDate?.toIso8601String().substring(0, 10),
  'notes':             i.notes,
};

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseBudgetRepository implements BudgetRepository {
  final SupabaseClient _client;
  SupabaseBudgetRepository(this._client);

  static const _kSelect = '*, suppliers(id, name)';

  @override
  Future<List<CostItem>> fetchForTrip(String tripId) async {
    final rows = await _client
        .from('cost_items')
        .select(_kSelect)
        .eq('trip_id', tripId)
        .order('created_at');
    return (rows as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<CostItem>> fetchAll(String teamId) async {
    final rows = await _client
        .from('cost_items')
        .select(_kSelect)
        .eq('team_id', teamId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CostItem> create(CostItem item, String teamId) async {
    final row = await _client
        .from('cost_items')
        .insert({
          ..._toRow(item, teamId: teamId),
          'created_by': _client.auth.currentUser?.id,
        })
        .select(_kSelect)
        .single();
    return _fromRow(row);
  }

  @override
  Future<CostItem> update(CostItem item) async {
    final row = await _client
        .from('cost_items')
        .update(_toRow(item))
        .eq('id', item.id)
        .select(_kSelect)
        .single();
    return _fromRow(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('cost_items').delete().eq('id', id);
  }

  @override
  Stream<List<CostItem>> watchForTrip(String tripId) {
    final controller = StreamController<List<CostItem>>.broadcast();

    Future<void> emit() async {
      try {
        final items = await fetchForTrip(tripId);
        if (!controller.isClosed) controller.add(items);
      } catch (_) {}
    }

    emit();

    final channel = _client
        .channel('cost_items:trip:$tripId:${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cost_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) => emit(),
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  @override
  Stream<List<CostItem>> watchAll(String teamId) {
    final controller = StreamController<List<CostItem>>.broadcast();

    Future<void> emit() async {
      try {
        final items = await fetchAll(teamId);
        if (!controller.isClosed) controller.add(items);
      } catch (_) {}
    }

    emit();

    final channel = _client
        .channel('cost_items:team:$teamId:${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cost_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (_) => emit(),
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}
