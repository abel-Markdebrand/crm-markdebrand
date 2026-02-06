import '../utils/odoo_utils.dart';

class Sale {
  final int id;
  final String name;
  final String partnerName;
  final int partnerId; // Nuevo campo para edición
  final double amountTotal;
  final String state;

  Sale({
    required this.id,
    required this.name,
    required this.partnerName,
    required this.partnerId,
    required this.amountTotal,
    required this.state,
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

    return Sale(
      id: json['id'] as int,
      name: OdooUtils.safeString(json['name']) == ''
          ? 'Sin nombre'
          : OdooUtils.safeString(json['name']),
      partnerName: pName,
      partnerId: pId,
      amountTotal: (json['amount_total'] as num?)?.toDouble() ?? 0.0,
      state: OdooUtils.safeString(json['state']) == ''
          ? 'draft'
          : OdooUtils.safeString(json['state']),
    );
  }
}
