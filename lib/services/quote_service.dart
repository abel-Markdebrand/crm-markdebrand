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
      'client_order_ref': clientOrderRef,
    };

    if (opportunityId != null) {
      // Defensive check for 'opportunity_id' existence in the server's model
      final exists = await _odoo.fieldExists(
        model: ApiRoutes.sales.model,
        fieldName: 'opportunity_id',
      );
      if (exists) {
        orderVals['opportunity_id'] = opportunityId;
      } else {
        debugPrint(
          "⚠️ Field 'opportunity_id' missing in sale.order. Skipping CRM link.",
        );
      }
    }

    if (paymentTermId != null) {
      orderVals['payment_term_id'] = paymentTermId;
    }

    if (commitmentDate != null) {
      orderVals['commitment_date'] = commitmentDate.toIso8601String();
    }

    if (lines != null && lines.isNotEmpty) {
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

      // 2. Use Wizard to Create Invoice (Standard Odoo Flow)
      try {
        debugPrint("Transactional: Launching Invoice Wizard...");

        // Step A: Create the Wizard Record
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
              'active_id': orderId,
            },
          },
        );

        if (wizId is int) {
          // Step B: Call 'create_invoices' on the created wizard
          // Note: 'create_invoices' usually returns a dictionary action (window action)
          // We ignore the return value and check the order for invoice_ids
          await _odoo.callKw(
            model: 'sale.advance.payment.inv',
            method: 'create_invoices',
            args: [wizId],
            kwargs: {
              // IMPORTANT: Context must be preserved for the wizard to know which order to invoice
              'context': {
                'active_ids': [orderId],
                'active_model': 'sale.order',
                'active_id': orderId,
                'open_invoices': false,
              },
            },
          );
        } else {
          throw Exception("Failed to create Invoice Wizard");
        }
      } catch (e) {
        debugPrint("Wizard Invoice Creation failed: $e");
        // Check if it's "Nothing to invoice" - Odoo raises UserError
        if (e.toString().contains("Nothing to invoice")) {
          // We can optionally ignore this if we just want to return existing invoices
          debugPrint(
            "Odoo says nothing to invoice. Proceeding to check existing invoices.",
          );
        } else {
          rethrow;
        }
      }

      debugPrint("Transactional: Retrieving generated Invoice ID...");
      // 3. Retrieve the Invoice ID from the Order
      // Retrying a few times might be needed if Odoo is slow, but usually it's synchronous.
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
          debugPrint("Success: Invoice Created with ID ${invoiceIds.last}");
          return invoiceIds.last as int;
        }
      }

      // If we got here, maybe no invoice was created?
      debugPrint(
        "Warning: No invoice ID found on order $orderId after wizard execution.",
      );
      return null;
    } catch (e) {
      debugPrint("Error in convertToInvoice: $e");
      rethrow;
    }
  }

  /// Generates the PDF for a Quote
  Future<String?> getQuotePdf(int orderId) async {
    return await _odoo.renderReport('sale.report_saleorder', [orderId]);
  }
}
