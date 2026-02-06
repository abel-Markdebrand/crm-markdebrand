import 'package:flutter/foundation.dart';
import 'odoo_service.dart';
import '../config/api_endpoints.dart';

class QuoteService {
  final OdooService _odoo = OdooService.instance;

  /// Fail-Safe Strategy to get a valid Pricelist ID
  /// 1. Search existing.
  /// 2. Create default if missing.
  /// 3. Fallback to ID 1.
  Future<int> getOrCreateDefaultPricelist() async {
    try {
      // Attempt 1: Search Existing
      final searchRes = await _odoo.callKw(
        model: ApiRoutes.products.priceListModel,
        method: ApiRoutes.auth.searchRead,
        args: [],
        kwargs: {
          'fields': ['id'],
          'limit': 1,
        },
      );

      if (searchRes != null && (searchRes as List).isNotEmpty) {
        return searchRes[0]['id'];
      }

      // Attempt 2: CREATE Default
      debugPrint("No pricelist found. Attempting to create one...");
      try {
        final newId = await _odoo.callKw(
          model: ApiRoutes.products.priceListModel,
          method: ApiRoutes.auth.create,
          args: [
            {
              'name': 'Public Pricelist (Mobile)',
              'currency_id': 1, // Assumption: USD/EUR is usually 1
              'active': true,
            },
          ],
        );
        if (newId is int) {
          return newId;
        }
      } catch (createError) {
        debugPrint("Failed to create pricelist: $createError");
      }

      // Attempt 3: Manual ID Override
      debugPrint("Forcing Pricelist ID 1");
      return 1;
    } catch (e) {
      debugPrint("Critical Error in Pricelist Strategy: $e");
      return 1; // Ultimate fallback
    }
  }

  /// Creates a draft Quote (sale.order).
  Future<int> createQuote({
    required int partnerId,
    required DateTime validityDate, // Expiration Date
    required int pricelistId,
    int? paymentTermId,
    String? note,
    String? clientOrderRef,
    double? weight,
    DateTime? commitmentDate, // Delivery Date
    List<Map<String, dynamic>>? lines,
    int? opportunityId,
  }) async {
    final orderVals = {
      'partner_id': partnerId,
      'validity_date': validityDate.toIso8601String().substring(0, 10),
      'pricelist_id': pricelistId,
      'note': note ?? '',
      'state': 'draft',
      // New Fields
      'client_order_ref': clientOrderRef,
      'opportunity_id': opportunityId,
    };

    if (paymentTermId != null) {
      orderVals['payment_term_id'] = paymentTermId;
    }
    // Note: 'weight' is usually calculated, but if we want to force it?
    // Odoo standard 'sale.order' might not have a writable 'weight' field (it sums lines).
    // Instead we might save it to a custom field or description if requested.
    // We will leave it out of standard write if Odoo usually computes it,
    // OR we check if 'commitment_date' exists.
    if (commitmentDate != null) {
      orderVals['commitment_date'] = commitmentDate.toIso8601String();
    }

    // If lines are provided, we can format them for One2many creation
    if (lines != null && lines.isNotEmpty) {
      // Odoo One2many format: [0, 0, {values}]
      orderVals['order_line'] = lines.map((line) => [0, 0, line]).toList();
    }

    final orderId = await _odoo.callKw(
      model: ApiRoutes.sales.model,
      method: ApiRoutes.sales.create,
      args: [orderVals],
    );

    return orderId as int;
  }

  /// Updates an existing Quote.
  Future<void> updateQuote(int orderId, Map<String, dynamic> vals) async {
    await _odoo.callKw(
      model: ApiRoutes.sales.model,
      method: ApiRoutes.sales.write,
      args: [
        [orderId],
        vals,
      ],
    );
  }

  /// Sends the Quote by email
  Future<void> markAsSent(int orderId) async {
    await updateQuote(orderId, {'state': 'sent'});
  }

  /// THE CRITICAL TRANSACTION: Convert Quote -> Invoice
  /// Updated to use Wizard Pattern (sale.advance.payment.inv) to avoid Private Method Error.
  Future<int?> convertToInvoice(int orderId) async {
    try {
      debugPrint("Transactional: Confirming Sale Order $orderId...");
      // 1. Confirm the Sale Order first
      try {
        await _odoo.callKw(
          model: ApiRoutes.sales.model,
          method: ApiRoutes.sales.confirm,
          args: [
            [orderId],
          ],
        );
      } catch (e) {
        debugPrint("Order likely already confirmed or cancellled ($e)");
        // Continue to check for invoices
      }

      // Check if Invoice ALREADY exists?
      final orderInfo = await _odoo.callKw(
        model: ApiRoutes.sales.model,
        method: 'read',
        args: [
          [orderId],
          ['invoice_ids'],
        ],
      );
      if (orderInfo != null && (orderInfo as List).isNotEmpty) {
        final existingInvoices = orderInfo[0]['invoice_ids'];
        if (existingInvoices is List && existingInvoices.isNotEmpty) {
          debugPrint(
            "Invoice ALREADY exists. Returning ID: ${existingInvoices.last}",
          );
          return existingInvoices.last;
        }
      }

      debugPrint("Transactional: Creating Invoice via public methods...");
      // dynamic result; // Removed unused variable
      // 2. Direct Invoice Creation (Bypassing Wizard to avoid "Registration" errors)
      try {
        // Try public 'action_invoice_create' (common in Odoo 12-14)
        await _odoo.callKw(
          model: ApiRoutes.sales.model,
          method: 'action_invoice_create',
          args: [
            [orderId],
          ],
        );
      } catch (e1) {
        debugPrint(
          "action_invoice_create failed ($e1), reverting to Wizard...",
        );
        // Revert to Wizard approach but with skip context
        try {
          final wizId = await _odoo.callKw(
            model: 'sale.advance.payment.inv',
            method: 'create',
            args: [
              {
                'advance_payment_method': 'delivered',
                'deduct_down_payments': true,
              },
            ],
            kwargs: {
              'context': {
                'active_ids': [orderId],
                'active_model': 'sale.order',
              },
            },
          );

          await _odoo.callKw(
            model: 'sale.advance.payment.inv',
            method: 'create_invoices',
            args: [wizId],
            kwargs: {
              'context': {
                'active_ids': [orderId],
                'active_model': 'sale.order',
                'open_invoices': false,
              },
            },
          );
        } catch (e2) {
          debugPrint(
            "Wizard failed too ($e2). Checking if invoice was created...",
          );
          // Check if invoice exists anyway before giving up
        }
      }

      debugPrint("Transactional: Retrieving generated Invoice ID...");
      // 4. Retrieve the Invoice ID from the Order
      final orderData = await _odoo.callKw(
        model: ApiRoutes.sales.model,
        method: 'read',
        args: [
          [orderId],
          ['invoice_ids'],
        ],
      );

      if (orderData != null && orderData is List && orderData.isNotEmpty) {
        final invoiceIds = orderData[0]['invoice_ids'];
        if (invoiceIds is List && invoiceIds.isNotEmpty) {
          debugPrint("Success: Invoice Created with ID ${invoiceIds[0]}");
          return invoiceIds[0] as int;
        }
      }

      return null;
    } catch (e) {
      debugPrint("Error in convertToInvoice: $e");
      rethrow;
    }
  }
}
