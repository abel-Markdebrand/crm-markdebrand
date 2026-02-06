/// Centralized API Endpoints configuration (Laravel-style Routes)
class ApiRoutes {
  // Config
  static const String dbName =
      'odoosp'; // This could be dynamic but putting here for now if needed

  // Modules
  static const auth = _AuthRoutes();
  static const crm = _CrmRoutes();
  static const sales = _SalesRoutes();
  static const accounting = _AccountingRoutes();
  static const products = _ProductRoutes();
  static const partners = _PartnerRoutes();
  static const files = _FileRoutes(); // Added
}

class _FileRoutes {
  const _FileRoutes();
  final String attachmentModel = 'ir.attachment';
  // Standard fields often used
  final String fieldDatas = 'datas'; // Base64 content
  final String fieldName = 'name';
  final String fieldResModel = 'res_model';
  final String fieldResId = 'res_id';
  final String fieldType = 'type'; // 'binary' or 'url'
  final String fieldMimetype = 'mimetype';
}

class _AuthRoutes {
  const _AuthRoutes();
  final String authenticate = 'web/session/authenticate';
  // Common methods
  final String searchRead = 'search_read';
  final String create = 'create';
  final String write = 'write';
  final String unlink = 'unlink';
  final String callKw = 'call_kw';
}

class _CrmRoutes {
  const _CrmRoutes();
  final String model = 'crm.lead';
  // Methods
  final String searchRead = 'search_read';
}

class _SalesRoutes {
  const _SalesRoutes();
  final String model = 'sale.order';
  final String lineModel = 'sale.order.line';

  // Methods
  final String create = 'create';
  final String write = 'write';
  final String confirm = 'action_confirm';
  final String createInvoices = '_create_invoices';
  // ..other specific methods
}

class _AccountingRoutes {
  const _AccountingRoutes();
  final String moveModel = 'account.move';
  final String lineModel = 'account.move.line';
  final String paymentTermModel = 'account.payment.term';

  // Methods
  final String post = 'action_post';
}

class _ProductRoutes {
  const _ProductRoutes();
  final String productModel = 'product.product';
  final String templateModel = 'product.template';
  final String priceListModel = 'product.pricelist';
}

class _PartnerRoutes {
  const _PartnerRoutes();
  final String model = 'res.partner';
}
