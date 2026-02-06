import '../services/odoo_service.dart';
import '../config/api_endpoints.dart';

class ProductService {
  final OdooService _odooService = OdooService.instance;

  /// Buscador de productos por nombre o referencia interna.
  /// Retorna lista de productos para selección visual.
  /// Filtra solo productos vendibles ('sale_ok' = true).
  Future<List<dynamic>> searchProducts(String query) async {
    // Si la consulta es vacía, traer los primeros 20 productos
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
}
