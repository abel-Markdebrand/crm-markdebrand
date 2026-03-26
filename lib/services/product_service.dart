import 'package:flutter/foundation.dart';
import '../services/odoo_service.dart';
import '../config/api_endpoints.dart';

class ProductService {
  final OdooService _odooService = OdooService.instance;

  /// Product searcher by name or internal reference.
  /// Returns a list of products for visual selection.
  /// Filters only sellable products ('sale_ok' = true).
  Future<List<dynamic>> searchProducts(String query) async {
    // If query is empty, fetch the first 20 products
    List<dynamic> domain = [
      ['sale_ok', '=', true],
    ];

    if (query.isNotEmpty) {
      domain.add('|'); // OR operator
      domain.add(['name', 'ilike', query]);
      domain.add(['default_code', 'ilike', query]);
    }

    final result = await _odooService.callKw(
      model: ApiRoutes.products.productModel,
      method: ApiRoutes.auth.searchRead,
      args: [],
      kwargs: {
        'domain': domain,
        'fields': ['id', 'name', 'default_code', 'list_price', 'uom_id'],
        'limit': 20,
      },
    );
    return result as List<dynamic>;
  }

  /// Creates a Direct Sale (Order + Confirmation -> Automatic Invoice)
  Future<bool> createDirectSale({
    required int partnerId,
    required int productId,
    double qty = 1.0,
  }) async {
    try {
      // 1. Get a valid pricelist
      final pricelistRes = await _odooService.callKw(
        model: ApiRoutes.products.priceListModel,
        method: ApiRoutes.auth.searchRead,
        args: [],
        kwargs: {
          'fields': ['id'],
          'limit': 1,
        },
      );
      int pricelistId = 1;
      if (pricelistRes is List && pricelistRes.isNotEmpty) {
        pricelistId = pricelistRes[0]['id'];
      }

      // 2. Create the Sale Order with the line included
      final orderId = await _odooService.callKw(
        model: ApiRoutes.sales.model,
        method: ApiRoutes.auth.create,
        args: [
          {
            'partner_id': partnerId,
            'pricelist_id': pricelistId,
            'state': 'draft',
            'order_line': [
              [
                0,
                0,
                {'product_id': productId, 'product_uom_qty': qty},
              ],
            ],
          },
        ],
      );

      if (orderId is! int) return false;

      // 3. Confirm with special context to trigger invoice automation
      await _odooService.confirmSale(
        orderId,
        context: {'is_mobile_order': true},
      );

      return true;
    } catch (e) {
      debugPrint("Direct Sale failed: $e");
      return false;
    }
  }
}
