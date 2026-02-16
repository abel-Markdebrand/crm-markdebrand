import '../models/crm_models.dart';
import '../services/odoo_service.dart';
import '../config/api_endpoints.dart';

class CrmService {
  final OdooService _odooService = OdooService.instance;

  // ---------------------------------------------------------------------------
  // CRM LOGIC
  // ---------------------------------------------------------------------------

  /// Obtiene las etapas del pipeline CRM
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

  /// Obtiene conteo de leads por etapa
  Future<Map<int, int>> getStageCounts() async {
    final result = await _odooService.callKw(
      model: ApiRoutes.crm.model,
      method: 'read_group',
      args: [],
      kwargs: {
        'domain': [
          ['type', '=', 'opportunity'],
        ],
        'fields': ['stage_id'],
        'groupby': ['stage_id'],
      },
    );

    final Map<int, int> counts = {};
    if (result is List) {
      for (var group in result) {
        if (group['stage_id'] is List) {
          final id = group['stage_id'][0] as int;
          final count = group['stage_id_count'] as int;
          counts[id] = count;
        }
      }
    }
    return counts;
  }

  /// Obtiene un Lead específico por ID
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
        ],
      },
    );
    if (result is List && result.isNotEmpty) {
      return CrmLead.fromJson(result[0]);
    }
    return null;
  }

  /// Obtiene leads por etapa para el usuario actual (o todos si es demo/admin)
  Future<List<CrmLead>> getPipeline(int stageId, {String? searchQuery}) async {
    final domain = [
      ['stage_id', '=', stageId],
      ['type', '=', 'opportunity'],
    ];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      domain.add(['name', 'ilike', searchQuery]);
    }

    final result = await _odooService.callKw(
      model: ApiRoutes.crm.model,
      method: ApiRoutes.crm.searchRead,
      args: [],
      kwargs: {
        'context': {'bin_size': true},
        'domain': domain,
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
        ],
        'limit': 50,
      },
    );
    return (result as List).map((json) => CrmLead.fromJson(json)).toList();
  }

  /// Actualiza los datos de un Lead (Cliente, Notas, etc.)
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

  /// Mover lead a otra etapa
  Future<void> updateLeadStage(int leadId, int newStageId) async {
    await updateLead(leadId, {'stage_id': newStageId});
  }

  /// Crea un nuevo Lead/Oportunidad
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

  /// Crea un pedido/presupuesto (Draft)
  Future<int> createSaleOrder({
    required int partnerId,
    int? opportunityId,
  }) async {
    return await _odooService.createSaleOrder(
      partnerId: partnerId,
      opportunityId: opportunityId,
    );
  }

  /// Agrega una línea al pedido
  Future<int> addOrderLine(int orderId, int productId, double qty) async {
    return await _odooService.addOrderLine(orderId, productId, qty);
  }

  /// Agrega línea con Nombre Personalizado
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

  /// Obtiene las líneas de un pedido
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

  /// Confirma la venta
  Future<void> confirmSale(int orderId) async {
    await _odooService.confirmSale(orderId);
  }

  /// Actualiza 'qty_delivered'
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

  /// Establece todas las líneas como entregadas
  Future<void> setAllLinesDelivered(int orderId) async {
    final lines = await getOrderLines(orderId);
    for (var line in lines) {
      final lineId = line['id'];
      final orderedQty = (line['product_uom_qty'] as num).toDouble();
      try {
        await updateLineDeliveredQty(lineId, orderedQty);
      } catch (e) {
        // Ignorar errores menores de actualización
      }
    }
  }

  /// Genera Factura
  Future<int?> generateInvoice(int orderId) async {
    try {
      final wizardId = await _odooService.callKw(
        model: 'sale.advance.payment.inv', // Wizard model
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
        method: ApiRoutes
            .sales
            .createInvoices, // Usually 'create_invoices' on wizard
        args: [wizardId],
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
    } catch (e) {
      return null;
    }
  }

  /// Publica la factura
  Future<void> postInvoice(int invoiceId) async {
    await _odooService.postInvoice(invoiceId);
  }

  /// Registra Pago (Mock)
  Future<void> registerPayment(int invoiceId) async {
    // Simulación
  }
}
