import '../utils/odoo_utils.dart';

class Sale {
  final int id;
  final String name;
  final String partnerName;
  final int partnerId; // Nuevo campo para edición
  final double amountTotal;
  final double amountUntaxed;
  final double amountTax;
  final String state;
  final String dateOrder;
  final String validityDate;
  final List<SaleLine> lines;
  final List<int> invoiceIds;
  final String note;
  final String salespersonName;

  Sale({
    required this.id,
    required this.name,
    required this.partnerName,
    required this.partnerId,
    required this.amountTotal,
    required this.amountUntaxed,
    required this.amountTax,
    required this.state,
    this.dateOrder = '',
    this.validityDate = '',
    this.lines = const [],
    this.invoiceIds = const [],
    this.note = '',
    this.salespersonName = '',
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    // partner_id en Odoo suele venir como [id, "Nombre"]
    String pName = 'Desconocido';
    int pId = 0;

    if (json['partner_id'] is List && json['partner_id'].length > 1) {
      pId = json['partner_id'][0] is int ? json['partner_id'][0] : 0;
      pName = OdooUtils.safeString(json['partner_id'][1]);
    } else if (json['partner_id'] is String) {
      pName = OdooUtils.safeString(json['partner_id']);
    }

    List<int> invIds = [];
    if (json['invoice_ids'] != null && json['invoice_ids'] is List) {
      invIds = (json['invoice_ids'] as List).cast<int>();
    }

    return Sale(
      id: json['id'] as int,
      name: OdooUtils.safeString(json['name']) == ''
          ? 'Sin nombre'
          : OdooUtils.safeString(json['name']),
      partnerName: pName,
      partnerId: pId,
      amountTotal: (json['amount_total'] as num?)?.toDouble() ?? 0.0,
      amountUntaxed: (json['amount_untaxed'] as num?)?.toDouble() ?? 0.0,
      amountTax: (json['amount_tax'] as num?)?.toDouble() ?? 0.0,
      state: OdooUtils.safeString(json['state']) == ''
          ? 'draft'
          : OdooUtils.safeString(json['state']),
      dateOrder: OdooUtils.safeString(json['date_order']),
      validityDate: OdooUtils.safeString(json['validity_date']),
      lines: [], // Lines will be loaded separately if needed
      invoiceIds: invIds,
      note: OdooUtils.safeString(json['note']),
      salespersonName: json['user_id'] is List && json['user_id'].length > 1
          ? OdooUtils.safeString(json['user_id'][1])
          : '',
    );
  }
}

class SaleLine {
  final int id;
  final String name;
  final double qty;
  final double priceUnit;
  final double priceTotal;

  SaleLine({
    required this.id,
    required this.name,
    required this.qty,
    required this.priceUnit,
    required this.priceTotal,
  });

  factory SaleLine.fromJson(Map<String, dynamic> json) {
    return SaleLine(
      id: json['id'] as int,
      name: json['name']?.toString() ?? 'Producto Desconocido',
      qty: (json['product_uom_qty'] as num?)?.toDouble() ?? 0.0,
      priceUnit: (json['price_unit'] as num?)?.toDouble() ?? 0.0,
      priceTotal: (json['price_total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
