import '../utils/odoo_utils.dart'; // Import utility

class CrmStage {
  final int id;
  final String name;
  final int sequence;

  CrmStage({required this.id, required this.name, required this.sequence});

  factory CrmStage.fromJson(Map<String, dynamic> json) {
    return CrmStage(
      id: json['id'],
      name: json['name'] ?? 'Sin Nombre',
      sequence: json['sequence'] ?? 0,
    );
  }
}

class CrmLead {
  final int id;
  final String name;
  final int? partnerId; // Nuevo campo
  final String? partnerName;
  final double expectedRevenue;
  final double probability;
  final String? description;
  final String? phone;
  final String? email;

  CrmLead({
    required this.id,
    required this.name,
    this.partnerId,
    this.partnerName,
    required this.expectedRevenue,
    required this.probability,
    this.description,
    this.phone,
    this.email,
  });

  factory CrmLead.fromJson(Map<String, dynamic> json) {
    int? pId;
    String pName = 'Cliente desconocido';

    // partner_id en Odoo es Many2one: [id, name] o false
    if (json['partner_id'] is List && json['partner_id'].length > 1) {
      pId = json['partner_id'][0];
      pName = json['partner_id'][1];
    } else if (json['partner_id'] is int) {
      // A veces si solo se lee el ID
      pId = json['partner_id'];
    }

    return CrmLead(
      id: json['id'],
      name: OdooUtils.safeString(json['name']),
      partnerId: pId,
      partnerName: pName,
      expectedRevenue: (json['expected_revenue'] as num?)?.toDouble() ?? 0.0,
      probability: (json['probability'] as num?)?.toDouble() ?? 0.0,
      description: OdooUtils.safeString(json['description']),
      phone: OdooUtils.safeString(json['phone']),
      email: OdooUtils.safeString(json['email_from']),
    );
  }
}
