import '../models/crm_models.dart';
import '../services/odoo_service.dart';
import '../config/api_endpoints.dart';

class CrmService {
  final OdooService _odooService = OdooService.instance;

  // ---------------------------------------------------------------------------
  // CRM LOGIC
  // ---------------------------------------------------------------------------

  /// Gets the CRM pipeline stages
  Future<List<CrmStage>> getPipelineStages() async {
    // Note: Stage model isn't in main config yet, adding here or hardcode specific
    final result = await _odooService.callKw(
      model: 'crm.stage',
      method: ApiRoutes.auth.searchRead,
      args: [],
      kwargs: {
        'context': {'bin_size': true},
        'domain': [],
        'fields': ['id', 'name', 'sequence'],
        'order': 'sequence asc',
      },
    );
    return (result as List).map((json) => CrmStage.fromJson(json)).toList();
  }

  /// Gets lead count per stage
  Future<Map<int, int>> getStageCounts() async {
    final result = await _odooService.callKw(
      model: ApiRoutes.crm.model,
      method: 'read_group',
      args: [],
      kwargs: {
        'domain': [], // No type filter to see all records
        'fields': ['stage_id'],
        'groupby': ['stage_id'],
      },
    );

    final Map<int, int> counts = {};
    if (result is List) {
      for (var group in result) {
        if (group['stage_id'] is List) {
          final id = group['stage_id'][0] as int;
          // Odoo read_group returns count as '<field>_count', 'crm_lead_count', or '__count' in newer versions
          final count =
              (group['stage_id_count'] ??
                      group['crm_lead_count'] ??
                      group['__count'] ??
                      0)
                  as int;
          counts[id] = count;
        }
      }
    }
    return counts;
  }

  /// Gets a specific Lead by ID
  Future<CrmLead?> getLeadById(int leadId) async {
    final result = await _odooService.callKw(
      model: ApiRoutes.crm.model,
      method: 'read',
      args: [
        [leadId],
      ],
      kwargs: {
        'fields': [
          'id',
          'name',
          'partner_id',
          'expected_revenue',
          'probability',
          'description',
          'phone',
          'email_from',
          'street',
          'city',
          'zip',
          'country_id',
          'function',
          'website',
          'priority',
          'tag_ids', // Added tag_ids to fields
        ],
      },
    );
    if (result is List && result.isNotEmpty) {
      return CrmLead.fromJson(result[0]);
    }
    return null;
  }

  /// Gets leads by stage for the current user (or all if demo/admin)
  Future<List<CrmLead>> getPipeline(int stageId, {String? searchQuery}) async {
    final domain = [
      ['stage_id', '=', stageId],
      // Removed ['type', '=', 'opportunity'] — some leads may not have this field set
      // which was causing them not to appear in the pipeline.
    ];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      domain.add(['name', 'ilike', searchQuery]);
    }

    final requestedFields = [
      'id',
      'name',
      'partner_id',
      'expected_revenue',
      'probability',
      'description',
      'phone',
      'email_from',
      'street',
      'city',
      'zip',
      'country_id',
      'function',
      'website',
      'priority',
    ];

    // Verify fields exist in parallel to improve performance
    final results = await Future.wait([
      _odooService.fieldExists(
        model: ApiRoutes.crm.model,
        fieldName: 'x_niche',
      ),
      _odooService.fieldExists(
        model: ApiRoutes.crm.model,
        fieldName: 'tag_ids',
      ),
    ]);

    final bool hasNiche = results[0];
    final bool hasTags = results[1];

    if (hasNiche) requestedFields.add('x_niche');
    if (hasTags) requestedFields.add('tag_ids');

    final result = await _odooService.callKw(
      model: ApiRoutes.crm.model,
      method: ApiRoutes.crm.searchRead,
      args: [],
      kwargs: {
        'context': {'bin_size': true},
        'domain': domain,
        'fields': requestedFields,
        'limit': 200, // Increased to see more Leads in production
      },
    );

    return (result as List).map((json) => CrmLead.fromJson(json)).toList();
  }

  /// Updates Lead data (Customer, Notes, etc.)
  Future<void> updateLead(int leadId, Map<String, dynamic> vals) async {
    await _odooService.callKw(
      model: ApiRoutes.crm.model,
      method: ApiRoutes.auth.write,
      args: [
        [leadId],
        vals,
      ],
    );
  }

  /// Move lead to another stage
  Future<void> updateLeadStage(int leadId, int newStageId) async {
    await updateLead(leadId, {'stage_id': newStageId});
  }

  /// Creates a new Lead/Opportunity
  Future<int> createLead(Map<String, dynamic> vals) async {
    final result = await _odooService.callKw(
      model: ApiRoutes.crm.model,
      method: ApiRoutes.auth.create,
      args: [vals],
    );
    return result as int;
  }

  // ---------------------------------------------------------------------------
  // SALES LOGIC (Migrated from SalesService)
  // ---------------------------------------------------------------------------

  /// Creates a sale order/quotation (Draft)
  Future<int> createSaleOrder({
    required int partnerId,
    int? opportunityId,
  }) async {
    return await _odooService.createSaleOrder(
      partnerId: partnerId,
      opportunityId: opportunityId,
    );
  }

  /// Adds a line to the order
  Future<int> addOrderLine(int orderId, int productId, double qty) async {
    return await _odooService.addOrderLine(orderId, productId, qty);
  }

  /// Adds a line with Custom Name
  Future<int> addOrderLineWithCustomName(
    int orderId,
    int productId,
    double qty,
    String customName,
  ) async {
    final vals = {
      'order_id': orderId,
      'product_id': productId,
      'product_uom_qty': qty,
      'name': customName,
    };

    final lineId = await _odooService.callKw(
      model: ApiRoutes.sales.lineModel,
      method: ApiRoutes.sales.create,
      args: [vals],
    );
    return lineId as int;
  }

  /// Gets the lines of an order
  Future<List<dynamic>> getOrderLines(int orderId) async {
    final result = await _odooService.callKw(
      model: ApiRoutes.sales.lineModel,
      method: ApiRoutes.auth.searchRead,
      args: [],
      kwargs: {
        'domain': [
          ['order_id', '=', orderId],
        ],
        'fields': [
          'product_id',
          'name',
          'product_uom_qty',
          'price_unit',
          'price_subtotal',
        ],
      },
    );
    return result as List<dynamic>;
  }

  /// Confirms the sale
  Future<void> confirmSale(int orderId) async {
    await _odooService.confirmSale(orderId);
  }

  /// Updates 'qty_delivered'
  Future<void> updateLineDeliveredQty(int lineId, double qty) async {
    await _odooService.callKw(
      model: ApiRoutes.sales.lineModel,
      method: ApiRoutes.sales.write,
      args: [
        [lineId],
        {'qty_delivered': qty},
      ],
    );
  }

  /// Sets all lines as delivered
  Future<void> setAllLinesDelivered(int orderId) async {
    final lines = await getOrderLines(orderId);
    for (var line in lines) {
      final lineId = line['id'];
      final orderedQty = (line['product_uom_qty'] as num).toDouble();
      try {
        await updateLineDeliveredQty(lineId, orderedQty);
      } catch (e) {
        // Ignore minor update errors
      }
    }
  }

  /// Generates Invoice
  Future<int?> generateInvoice(int orderId) async {
    final wizardId = await _odooService.callKw(
      model: 'sale.advance.payment.inv',
      method: ApiRoutes.sales.create,
      args: [
        {'advance_payment_method': 'delivered'},
      ],
      kwargs: {
        'context': {
          'active_model': ApiRoutes.sales.model,
          'active_ids': [orderId],
          'active_id': orderId,
        },
      },
    );

    await _odooService.callKw(
      model: 'sale.advance.payment.inv',
      method: ApiRoutes.sales.createInvoices,
      args: [
        [wizardId],
      ],
      kwargs: {
        'context': {
          'active_model': ApiRoutes.sales.model,
          'active_ids': [orderId],
          'active_id': orderId,
        },
      },
    );

    final orderRes = await _odooService.callKw(
      model: ApiRoutes.sales.model,
      method: 'read',
      args: [
        [orderId],
      ],
      kwargs: {
        'fields': ['invoice_ids'],
      },
    );

    if (orderRes != null && (orderRes as List).isNotEmpty) {
      final invoiceIds = orderRes[0]['invoice_ids'] as List;
      if (invoiceIds.isNotEmpty) {
        return invoiceIds.last as int;
      }
    }
    return null;
  }

  /// Posts the invoice
  Future<void> postInvoice(int invoiceId) async {
    await _odooService.postInvoice(invoiceId);
  }

  /// Registers Payment (Mock)
  Future<void> registerPayment(int invoiceId) async {
    // Simulation
  }

  /// Gets available tags in Odoo
  Future<List<Map<String, dynamic>>> getAvailableTags() async {
    final result = await _odooService.callKw(
      model: 'crm.tag',
      method: ApiRoutes.auth.searchRead,
      args: [],
      kwargs: {
        'fields': ['id', 'name', 'color'],
        'order': 'name asc',
      },
    );
    return (result as List).cast<Map<String, dynamic>>();
  }
}
