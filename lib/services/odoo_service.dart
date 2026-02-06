import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import '../models/sale.dart';
import '../models/voip_config.dart';

// Definición de excepciones personalizadas para manejo de errores de negocio
class ClientRequiredException implements Exception {
  final String message;
  ClientRequiredException(this.message);
  @override
  String toString() => message;
}

class OdooServiceException implements Exception {
  final String message;
  OdooServiceException(this.message);
  @override
  String toString() => message;
}

class OdooService {
  // ---------------------------------------------------------------------------
  // FASE 0: REFACTORIZACIÓN CRÍTICA DE ARQUITECTURA
  // Singleton Estático y Cliente Privado
  // ---------------------------------------------------------------------------

  static final OdooService instance = OdooService._internal();

  OdooService._internal();

  OdooClient? _client;
  String? _baseUrl; // Added for VoIP Controller access

  // Getter público para verificar si está inicializado (útil para guardias de navegación)
  bool get isInitialized => _client != null;

  /// Inicializa el cliente con la URL del servidor
  void init(String url) {
    _client = OdooClient(url);
    _baseUrl = url;
  }

  /// Gestiona la autenticación de sesión
  Future<void> authenticate(String db, String user, String password) async {
    if (_client == null) {
      throw OdooServiceException("Client not initialized. Call init() first.");
    }
    try {
      await _client!.authenticate(db, user, password);
    } on OdooException catch (e) {
      debugPrint("Authentication error: $e");
      throw OdooServiceException(
        "Error de autenticación: Verifica tus credenciales.",
      );
    } catch (e) {
      debugPrint("Authentication error (Unknown): $e");
      throw OdooServiceException(
        "Error de conexión: No se pudo contactar al servidor.",
      );
    }
  }

  /// Helper para obtener el UID del usuario actual
  int? get currentUserId {
    return _client?.sessionId?.userId;
  }

  // Cache for VoIP Credentials in case of subsequent RPC failures
  Map<String, dynamic>? _cachedVoipData;

  /// Obtiene los detalles del perfil del usuario actual
  Future<Map<String, dynamic>> getUserProfile() async {
    final uid = currentUserId;
    if (uid == null) throw OdooServiceException("No user logged in.");

    // 1. Fetch User Data (Added VoIP fields here!)
    final userRes = await callKw(
      model: 'res.users',
      method: 'read',
      args: [
        [uid],
      ],
      kwargs: {
        'fields': [
          'name',
          'login',
          'partner_id',
          'lang',
          'tz',
          'company_id',
          // VoIP Fields cached on login
          'voip_username',
          'voip_secret',
          'voip_provider_id',
        ],
      },
    );

    if (userRes is! List || userRes.isEmpty) {
      throw OdooServiceException("User data not found.");
    }

    final userData = userRes[0] as Map<String, dynamic>;

    // Store in cache for fetchVoipConfig fallback
    _cachedVoipData = {
      'voip_username': userData['voip_username'],
      'voip_secret': userData['voip_secret'],
      'voip_provider_id': userData['voip_provider_id'],
    };
    debugPrint("💾 OdooService: Cached VoIP Setup -> $_cachedVoipData");

    // 2. Fetch Partner Data (Image, Phone, Function)
    int? partnerId;
    if (userData['partner_id'] is List && userData['partner_id'].isNotEmpty) {
      partnerId = userData['partner_id'][0];
    }

    if (partnerId != null) {
      final partnerRes = await callKw(
        model: 'res.partner',
        method: 'read',
        args: [
          [partnerId],
        ],
        kwargs: {
          'fields': ['image_1920', 'phone', 'function', 'email'],
        },
      );
      if (partnerRes is List && partnerRes.isNotEmpty) {
        userData.addAll(partnerRes[0] as Map<String, dynamic>);
      }
    }

    return userData;
  }

  /// Método centralizado para realizar llamadas a Odoo con manejo de errores robusto
  /// Accesible por otros servicios (CrmService, ProductService, etc.)
  Future<dynamic> callKw({
    required String model,
    required String method,
    required List<dynamic> args,
    Map<String, dynamic>? kwargs,
  }) async {
    if (_client == null) {
      throw OdooServiceException("Client not initialized. Please login first.");
    }

    try {
      debugPrint("RPC Call -> Model: $model, Method: $method");
      return await _client!.callKw({
        'model': model,
        'method': method,
        'args': args,
        'kwargs': kwargs ?? {},
      });
    } on OdooException catch (e) {
      debugPrint("Odoo RPC Error ($model.$method): $e");
      throw OdooServiceException("Error del servidor Odoo: ${e.message}");
    } catch (e) {
      debugPrint("Unknown Error ($model.$method): $e");
      // Mapeo específico para errores de conexión
      if (e.toString().contains("SocketException") ||
          e.toString().contains("Network is unreachable")) {
        throw OdooServiceException(
          "Error de conexión: Verifica tu internet o el servidor.",
        );
      }
      throw OdooServiceException("Error desconocido: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // RESTORED: CONTACTS (res.partner)
  // Methods restored to fix ContactsScreen and other legacy usages
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getContacts() async {
    final result = await callKw(
      model: 'res.partner',
      method: 'search_read',
      args: [],
      kwargs: {
        'context': {'bin_size': true},
        'domain': [],
        // 'filter_domain': [['type', '=', 'contact']], // Optional: filter only contacts
        'fields': [
          'id',
          'name',
          'email',
          'phone',
          'vat',
          'function', // Job Position
          'parent_name', // Company Name
          'comment', // Notes (Inquiry Details)
          'create_date', // Creation Date
        ],
        'limit': 50,
      },
    );
    return result as List<dynamic>;
  }

  Future<int> createContact(Map<String, dynamic> data) async {
    final result = await callKw(
      model: 'res.partner',
      method: 'create',
      args: [data],
    );
    return result as int;
  }

  Future<void> updateContact(int id, Map<String, dynamic> data) async {
    await callKw(
      model: 'res.partner',
      method: 'write',
      args: [
        [id],
        data,
      ],
    );
  }

  Future<void> deleteContact(int id) async {
    await callKw(
      model: 'res.partner',
      method: 'unlink',
      args: [
        [id],
      ],
    );
  }

  /// Fetches full details for a single contact
  Future<Map<String, dynamic>> getContactDetail(int id) async {
    final result = await callKw(
      model: 'res.partner',
      method: 'read',
      args: [
        [id],
      ],
      kwargs: {
        'fields': [
          'id',
          'name',
          'email',
          'phone',
          'mobile', // Often useful
          'website',
          'vat', // Tax ID
          'function', // Job Position
          'title', // Title (e.g. Mister)
          'parent_name', // Company Name text
          'comment', // Notes
          // Address
          'street',
          'street2',
          'city',
          'state_id', // [id, name]
          'zip',
          'country_id', // [id, name]
          // Config
          'is_company',
          'user_id', // Salesperson [id, name]
          'property_payment_term_id', // Payment Terms
          // Image
          'image_1920',
        ],
      },
    );
    if (result is List && result.isNotEmpty) {
      return result[0] as Map<String, dynamic>;
    }
    throw OdooServiceException("Contact not found");
  }

  // ---------------------------------------------------------------------------
  // RESTORED: SALES LIST & CRUD
  // Methods restored or updated to support SalesScreen listing
  // ---------------------------------------------------------------------------

  Future<List<Sale>> getSales() async {
    final result = await callKw(
      model: 'sale.order',
      method: 'search_read',
      args: [],
      kwargs: {
        'context': {'bin_size': true},
        'domain': [], // Could filter by my sales if needed
        'fields': [
          'id',
          'name',
          'partner_id',
          'amount_total',
          'state',
          'date_order',
        ],
        'order': 'date_order desc',
        'limit': 50,
      },
    );
    // Verificar si el resultado es nulo o vacío antes de mapear
    if (result == null) return [];

    // Proteger el mapeo contra errores de estructura JSON
    try {
      return (result as List).map((json) => Sale.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error parsing Sales: $e");
      return [];
    }
  }

  Future<int> createSale(Map<String, dynamic> vals) async {
    final result = await callKw(
      model: 'sale.order',
      method: 'create',
      args: [vals],
    );
    return result as int;
  }

  Future<void> updateSale(int id, Map<String, dynamic> vals) async {
    await callKw(
      model: 'sale.order',
      method: 'write',
      args: [
        [id],
        vals,
      ],
    );
  }

  // deleteSale already exists as helper in legacy code? Restoring just in case
  Future<void> deleteSale(int id) async {
    await callKw(
      model: 'sale.order',
      method: 'unlink',
      args: [
        [id],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FASE 1: CRM (PIPELINE DE VENTAS)
  // ---------------------------------------------------------------------------

  /// Consultar crm.stage. Ordenar por sequence. Retornar lista limpia.
  Future<List<dynamic>> getCrmStages() async {
    final result = await callKw(
      model: 'crm.stage',
      method: 'search_read',
      args: [],
      kwargs: {
        'context': {'bin_size': true},
        'domain': [], // Se pueden añadir filtros si es necesario
        'fields': ['id', 'name', 'sequence'],
        'order': 'sequence asc',
      },
    );
    return result as List<dynamic>;
  }

  /// Consultar crm.tag para etiquetas de Oportunidades.
  Future<List<dynamic>> getCrmTags() async {
    final result = await callKw(
      model: 'crm.tag',
      method: 'search_read',
      args: [],
      kwargs: {
        'fields': ['id', 'name', 'color'],
        'limit': 100,
      },
    );
    return result as List<dynamic>;
  }

  /// Consultar crm.lead. Mis Oportunidades por Etapa.
  Future<List<dynamic>> getMyOpportunities(int stageId) async {
    final uid = currentUserId;
    if (uid == null) throw OdooServiceException("Usuario no identificado.");

    final result = await callKw(
      model: 'crm.lead',
      method: 'search_read',
      args: [],
      kwargs: {
        'context': {'bin_size': true},
        // Filtro: Stage ID, Type = Opportunity (User ID removido para ver todos durante testing/demo)
        'domain': [
          // ['user_id', '=', uid], // COMENTADO: El usuario indicó que es un demo y los datos pueden no estar asignados a él
          ['stage_id', '=', stageId],
          ['type', '=', 'opportunity'],
        ],
        'fields': [
          'id',
          'name',
          'partner_id',
          'expected_revenue',
          'probability',
          'description', // Restaurado por solicitud del usuario
        ],
        'limit': 50, // Paginación podría ser necesaria en el futuro
      },
    );
    return result as List<dynamic>;
  }

  /// Método write para mover tarjetas entre columnas (Actualizar Etapa del Lead).
  Future<void> updateLeadStage(int leadId, int newStageId) async {
    await callKw(
      model: 'crm.lead',
      method: 'write',
      args: [
        [leadId],
        {'stage_id': newStageId},
      ],
    );
  }

  /// Crea un nuevo Lead/Oportunidad en Odoo (crm.lead)
  Future<int> createLead(Map<String, dynamic> vals) async {
    final result = await callKw(
      model: 'crm.lead',
      method: 'create',
      args: [vals],
    );
    return result as int;
  }

  /// Obtiene los detalles de un Lead/Oportunidad por ID
  Future<Map<String, dynamic>> getLeadDetail(int leadId) async {
    final result = await callKw(
      model: 'crm.lead',
      method: 'read',
      args: [
        [leadId],
      ],
      kwargs: {
        'fields': [
          'name',
          'partner_id',
          'contact_name',
          'email_from',
          'phone',
          'description',
          'team_id',
          'user_id',
          'campaign_id',
          'medium_id',
          'source_id',
          'street',
          'city',
          'zip',
          'tag_ids',
        ],
      },
    );
    if (result is List && result.isNotEmpty) {
      return result[0] as Map<String, dynamic>;
    }
    throw OdooServiceException("Lead/Oportunidad no encontrada.");
  }

  // ---------------------------------------------------------------------------
  // FASE 2: EL NÚCLEO DE VENTAS (Cotización vinculada)
  // ---------------------------------------------------------------------------

  /// Crea una venta a partir de datos de un Lead.
  /// Valida que exista un cliente asociado.
  Future<int> createSaleFromLead(Map<String, dynamic> leadData) async {
    // leadData debe contener al menos 'partner_id' (que viene como [id, name] o flase)
    final partnerField = leadData['partner_id'];

    // En Odoo, si el campo es Many2one y está vacío, suele venir como false
    if (partnerField == null || partnerField is bool) {
      throw ClientRequiredException(
        "La oportunidad no tiene un cliente asignado.",
      );
    }

    int partnerId;
    if (partnerField is List && partnerField.isNotEmpty) {
      partnerId = partnerField[0];
    } else if (partnerField is int) {
      partnerId = partnerField;
    } else {
      throw ClientRequiredException("Formato de cliente inválido.");
    }

    final opportunityId = leadData['id'] as int?;

    // Llama a createSaleOrder pasando el lead_id para vincular
    return await createSaleOrder(
      partnerId: partnerId,
      opportunityId: opportunityId,
    );
  }

  /// Crea la cabecera del pedido de venta (sale.order).
  Future<int> createSaleOrder({
    required int partnerId,
    int? opportunityId,
  }) async {
    final Map<String, dynamic> vals = {
      'partner_id': partnerId,
      'state': 'draft', // Opcional, por defecto es draft/sent
    };

    // Dato Clave: Vinculación CRM -> Venta
    if (opportunityId != null) {
      vals['opportunity_id'] = opportunityId;
    }

    final orderId = await callKw(
      model: 'sale.order',
      method: 'create',
      args: [vals],
    );

    return orderId as int;
  }

  /// Agrega una línea de producto al pedido (sale.order.line).
  /// Permite a Odoo calcular precios unitarios e impuestos automáticamente.
  Future<int> addOrderLine(int orderId, int productId, double qty) async {
    final lineId = await callKw(
      model: 'sale.order.line',
      method: 'create',
      args: [
        {
          'order_id': orderId,
          'product_id': productId,
          'product_uom_qty': qty,
          // No enviamos price_unit explícitamente para que Odoo use lista de precios
        },
      ],
    );
    return lineId as int;
  }

  // ---------------------------------------------------------------------------
  // FASE 3: CIERRE TRANSACCIONAL (Facturar y Cobrar)
  // ---------------------------------------------------------------------------

  /// Confirma la venta (Pasa de Presupuesto a Pedido de Venta).
  Future<void> confirmSale(int orderId) async {
    await callKw(
      model: 'sale.order',
      method: 'action_confirm',
      args: [
        [orderId],
      ],
    );
  }

  /// Publica la factura (Validez fiscal).
  Future<void> postInvoice(int invoiceId) async {
    await callKw(
      model: 'account.move',
      method: 'action_post',
      args: [
        [invoiceId],
      ],
    );
  }

  /// Marca la factura como pagada (Versión MVP Simplificada).
  Future<void> registerPaymentStub(int invoiceId) async {
    // NOTA: El flujo real de Odoo requiere crear un account.payment y linkearlo o usar el wizard.
    // Para este MVP, ejecutamos un wizard simplificado o marcamos lo necesario.
    // Dada la complejidad, en muchos MVP "móviles rápidos" se llama a action_register_payment
    // que devuelve una acción de ventana, y luego se crea el pago.
    // Aquí asumiremos una implementación futura o un wizard custom.
    // Por ahora, solo logueamos la intención.
    debugPrint("Simulando registro de pago para factura $invoiceId");

    // Implementación real requeriría:
    // 1. Obtener context de la factura
    // 2. Crear 'account.payment.register' con el context active_ids=[invoiceId]
    // 3. Llamar action_create_payments()
  }

  // ---------------------------------------------------------------------------
  // FASE 4: LEGAL (Firma Digital)
  // ---------------------------------------------------------------------------

  /// Sube la imagen de la firma y la asocia al pedido de venta.
  Future<void> uploadSignature(int orderId, String base64Image) async {
    await callKw(
      model: 'ir.attachment',
      method: 'create',
      args: [
        {
          'name': 'signature_sale_$orderId.png',
          'type': 'binary',
          'datas': base64Image,
          'res_model': 'sale.order',
          'res_id': orderId,
          'mimetype': 'image/png',
        },
      ],
    );

    // Opcional: Si el modelo sale.order tiene un campo 'signature' binario o similar,
    // también se podría actualizar directamente allí:
    // await callKw(model: 'sale.order', method: 'write', args: [[orderId], {'signed_by': ..., 'signature': base64Image}]);
  }

  // ---------------------------------------------------------------------------
  // OTROS MÉTODOS DE SOPORTE (Productos, Partners, etc.)
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> searchProducts(String query) async {
    return await callKw(
      model: 'product.product', // Especificado en diccionario: product.product
      method: 'search_read',
      args: [],
      kwargs: {
        'domain': [
          ['name', 'ilike', query],
          ['sale_ok', '=', true],
        ],
        'fields': ['id', 'name', 'list_price', 'uom_id'],
        'limit': 20,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // REPORTING & ANALYTICS
  // ---------------------------------------------------------------------------

  /// Obtiene estadísticas básicas de Facturación (Mocked/Calculated)
  Future<Map<String, dynamic>> getInvoiceStats() async {
    // 1. Total Receivables (Facturas Publicadas y No Pagadas)
    final receivablesRes = await callKw(
      model: 'account.move',
      method: 'search_read',
      args: [],
      kwargs: {
        'domain': [
          ['move_type', '=', 'out_invoice'],
          ['state', '=', 'posted'],
          [
            'payment_state',
            'in',
            ['not_paid', 'partial'],
          ],
        ],
        'fields': ['name', 'partner_id', 'amount_residual', 'invoice_date_due'],
      },
    );
    double totalReceivables = 0.0;
    List<dynamic> unpaidInvoices = []; // Store list for UI

    if (receivablesRes is List) {
      unpaidInvoices = receivablesRes;
      for (var inv in receivablesRes) {
        totalReceivables += (inv['amount_residual'] as num?)?.toDouble() ?? 0.0;
      }
    }

    // 2. Overdue Count (Vencidas)
    final today = DateTime.now().toIso8601String().split('T')[0];
    final overdueRes = await callKw(
      model: 'account.move',
      method: 'search_count',
      args: [
        [
          ['move_type', '=', 'out_invoice'],
          ['state', '=', 'posted'],
          [
            'payment_state',
            'in',
            ['not_paid', 'partial'],
          ],
          ['invoice_date_due', '<', today],
        ],
      ],
    );
    int overdueCount = overdueRes is int ? overdueRes : 0;

    // 3. Recent Payments (Pagos Recientes)
    final paymentsRes = await callKw(
      model: 'account.payment',
      method: 'search_read',
      args: [],
      kwargs: {
        'domain': [
          ['payment_type', '=', 'inbound'], // Incoming money
          ['state', '=', 'posted'],
        ],
        'fields': ['partner_id', 'date', 'amount', 'currency_id'],
        'order': 'date desc',
        'limit': 5,
      },
    );

    return {
      'total_receivables': totalReceivables,
      'overdue_count': overdueCount,
      'unpaid_invoices': unpaidInvoices, // Returned for Pay & Send flow
      'cash_flow_trend': 12.4, // Simulamos tendencia positiva
      'recent_payments': paymentsRes ?? [],
    };
  }

  /// Obtiene estadísticas de Ventas (Revenue, Count)
  Future<Map<String, dynamic>> getSalesStats() async {
    // Calcular Total Revenue de Ventas Confirmadas
    final revenueRes = await callKw(
      model: 'sale.order',
      method: 'search_read',
      args: [],
      kwargs: {
        'domain': [
          [
            'state',
            'in',
            ['sale', 'done'],
          ], // Solo ventas confirmadas
        ],
        'fields': ['amount_total'],
      },
    );

    double totalRevenue = 0.0;
    int dealCount = 0;

    if (revenueRes is List) {
      dealCount = revenueRes.length;
      for (var sale in revenueRes) {
        totalRevenue += (sale['amount_total'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return {
      'total_revenue': totalRevenue,
      'deal_count': dealCount,
      'avg_deal_size': dealCount > 0 ? totalRevenue / dealCount : 0.0,
    };
  }

  /// Obtiene estadísticas de Productos (Top Sellers - Simulado con búsqueda simple)
  Future<List<dynamic>> getProductStats() async {
    // En un escenario real, haríamos un read_group sobre sale.report
    // Aquí simplemente traemos productos caros como "Top"
    final products = await callKw(
      model: 'product.product',
      method: 'search_read',
      args: [],
      kwargs: {
        'domain': [
          ['sale_ok', '=', true],
        ],
        'fields': [
          'name',
          'list_price',
          'sales_count',
        ], // sales_count es campo computado
        'order': 'list_price desc',
        'limit': 5,
      },
    );
    return products is List ? products : [];
  }

  // ---------------------------------------------------------------------------
  // FACTURACIÓN & PAGOS (New Request)
  // ---------------------------------------------------------------------------

  /// Registra el pago completo de una factura
  Future<void> registerFullPayment(int invoiceId) async {
    // 0. Fetch Invoice Details (Amount to Pay)
    final invRes = await callKw(
      model: 'account.move',
      method: 'read',
      args: [
        [invoiceId],
        ['amount_residual', 'currency_id'],
      ],
    );
    if (invRes == null || (invRes as List).isEmpty) {
      throw OdooServiceException("Invoice not found");
    }
    final inv = invRes[0];
    final amountToPay = inv['amount_residual'];
    final currencyId = (inv['currency_id'] is List)
        ? inv['currency_id'][0]
        : inv['currency_id'];

    // 1. Obtener el Journal (Diario) de Banco o Efectivo para pagar
    final journals = await callKw(
      model: 'account.journal',
      method: 'search_read',
      args: [],
      kwargs: {
        'domain': [
          [
            'type',
            'in',
            ['bank', 'cash'],
          ],
        ],
        'fields': ['id'],
        'limit': 1,
      },
    );

    if (journals == null || (journals as List).isEmpty) {
      throw OdooServiceException(
        "No se encontró un diario de pago (Banco/Efectivo).",
      );
    }
    final journalId = journals[0]['id'];

    // 2. Crear el Wizard de Pago (account.payment.register)
    final wizardContext = {
      'active_model': 'account.move',
      'active_ids': [invoiceId],
      'active_id': invoiceId,
    };

    final wizardId = await callKw(
      model: 'account.payment.register',
      method: 'create',
      args: [
        {
          'journal_id': journalId,
          'amount': amountToPay,
          'currency_id': currencyId,
          'payment_date': DateTime.now().toString().substring(0, 10),
        },
      ],
      kwargs: {'context': wizardContext},
    );

    // 3. Confirmar el Pago (action_create_payments)
    await callKw(
      model: 'account.payment.register',
      method: 'action_create_payments',
      args: [
        [wizardId],
      ],
      kwargs: {'context': wizardContext},
    );
  }

  // ---------------------------------------------------------------------------
  // FASE 5: VOIP (SIP CREDENTIALS)
  // ---------------------------------------------------------------------------

  /// Obtiene credenciales SIP Normalizadas via API (o Simulación Segura)
  /// Retorna un objeto [VoipConfig] validado.
  // ---------------------------------------------------------------------------
  // FASE 5: VOIP (PRODUCCIÓN - AXIVOX INTEGRATION)
  // ---------------------------------------------------------------------------

  /// Fetches the VoIP configuration for the current user.
  /// Follows strict production contract: {sip_login, sip_password, domain, ws_url}
  /// Note: Uses "Safe Simulation" until backend endpoint /api/voip/config is deployed.
  Future<VoipConfig?> fetchVoipConfig() async {
    debugPrint("🚀 OdooService: fetchVoipConfig() initiating...");

    final uid = currentUserId;
    if (uid == null) {
      debugPrint("❌ OdooService: No user logged in.");
      throw OdooServiceException("No user logged in.");
    }

    // Vars to capture from Odoo or fallback
    String sipLogin = "";
    String sipPassword = "";
    String domain = "";
    String wsUrl = "";

    try {
      // 1. Try Fetch from Odoo
      final userSettingsRes = await callKw(
        model: 'res.users',
        method: 'search_read',
        args: [],
        kwargs: {
          'domain': [
            ['id', '=', uid],
          ],
          'fields': ['voip_username', 'voip_secret', 'voip_provider_id'],
          'limit': 1,
        },
      );

      if (userSettingsRes != null && (userSettingsRes as List).isNotEmpty) {
        final userData = userSettingsRes[0] as Map<String, dynamic>;
        sipLogin = userData['voip_username']?.toString() ?? "";
        sipPassword = userData['voip_secret']?.toString() ?? "";

        // Provider Strategy
        final providerField = userData['voip_provider_id'];
        if (providerField is List && providerField.isNotEmpty) {
          final providerName = providerField[1].toString();
          debugPrint("✅ OdooService: Provider detected -> $providerName");

          if (providerName.toLowerCase().contains("axivox")) {
            domain = "pabx.axivox.com";
            wsUrl = "wss://pabx.axivox.com:3443";
          } else if (providerName.toLowerCase().contains("asterisk") ||
              providerName.toLowerCase().contains("smartwash")) {
            domain = "pbx.smartwashproaviation.com";
            wsUrl = "wss://pbx.smartwashproaviation.com/asterisk/ws";
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ OdooService: Failed to fetch SIP config from Odoo: $e");

      // FALLBACK: Use Cached Data if available (fetched during login)
      if (_cachedVoipData != null) {
        debugPrint("ℹ️ OdooService: Using Cached Credentials");
        sipLogin = _cachedVoipData!['voip_username']?.toString() ?? "";
        sipPassword = _cachedVoipData!['voip_secret']?.toString() ?? "";

        final providerField = _cachedVoipData!['voip_provider_id'];
        if (providerField is List && providerField.isNotEmpty) {
          final providerName = providerField[1].toString();
          if (providerName.toLowerCase().contains("axivox")) {
            domain = "pabx.axivox.com";
            wsUrl = "wss://pabx.axivox.com:3443";
          } else if (providerName.toLowerCase().contains("asterisk") ||
              providerName.toLowerCase().contains("smartwash")) {
            domain = "pbx.smartwashproaviation.com";
            wsUrl = "wss://pbx.smartwashproaviation.com/asterisk/ws";
          }
        }
      }
    }

    // --- STRATEGY: DYNAMIC FALLBACK (IP-Based / Dev) ---
    // If domain/wsUrl are empty (either RPC failed OR provider not set), infer.
    if ((domain.isEmpty || wsUrl.isEmpty) && _baseUrl != null) {
      debugPrint("⚠️ OdooService: Config missing/incomplete. Inferring...");
      try {
        final uri = Uri.parse(_baseUrl!);
        final host = uri.host;
        final scheme = uri.scheme;

        if (domain.isEmpty) domain = host;

        if (wsUrl.isEmpty) {
          if (scheme == 'https') {
            wsUrl = "wss://$host:8089/ws";
          } else {
            wsUrl = "ws://$host:8071/ws";
          }
        }
        debugPrint("🔧 OdooService: Inferred -> Domain: $domain, WS: $wsUrl");
      } catch (e) {
        debugPrint("❌ OdooService: Inference failed: $e");
      }
    }

    // FINAL VALIDATION
    // Logic: If RPC failed, we might have empty login/pass.
    // If so, we can't proceed. BUT, if RPC succeeded but just missing provider, we are good.
    if (sipLogin.isEmpty || sipPassword.isEmpty) {
      // LAST RESORT: Try using Odoo Login (email) as SIP User?
      // Only if we really want to push it.
      // For now, let's fail gracefully if no credentials found.
      debugPrint("❌ OdooService: Missing credentials after all attempts.");
      return null;
    }

    // Construct Config
    final configMap = {
      "sip_login": sipLogin,
      "sip_password": sipPassword,
      "domain": domain,
      "ws_url": wsUrl,
    };

    debugPrint("📦 OdooService: Config Constructed -> $configMap");
    return VoipConfig.fromJson(configMap);
  }

  // ---------------------------------------------------------------------------
  // VOIP CONTROLLER INTEGRATION (Custom Endpoints)
  // ---------------------------------------------------------------------------

  /// Calls /voip/get_country_code (JSON-RPC)
  Future<String?> voipGetCountryCode(String phoneNumber) async {
    if (_client == null || _baseUrl == null) return null;

    final uri = Uri.parse('$_baseUrl/voip/get_country_code');

    // JSON-RPC 2.0 Payload
    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "params": {"phone_number": phoneNumber},
      "id": DateTime.now().millisecondsSinceEpoch,
    };

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=${_client!.sessionId!.id}',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body.containsKey('result')) {
          return body['result'] as String?;
        }
      }
    } catch (e) {
      debugPrint("VoIP Country Code Error: $e");
    }
    return null;
  }

  /// Calls /voip/upload_recording (HTTP POST Multipart)
  Future<void> voipUploadRecording(int callId, String filePath) async {
    if (_client == null || _baseUrl == null) return;

    final uri = Uri.parse('$_baseUrl/voip/upload_recording/$callId');
    final request = http.MultipartRequest('POST', uri);

    // Auth Cookie
    request.headers['Cookie'] = 'session_id=${_client!.sessionId!.id}';

    // Add File
    if (File(filePath).existsSync()) {
      request.files.add(await http.MultipartFile.fromPath('ufile', filePath));

      try {
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        debugPrint("Upload Recording Status: ${response.statusCode}");
      } catch (e) {
        debugPrint("Upload Recording Error: $e");
      }
    }
  }
}
