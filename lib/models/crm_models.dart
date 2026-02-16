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
  final String? street;
  final String? city;
  final String? zip;
  final String? countryName; // country_id -> name
  final String? function;
  final String? website;
  final String? priority;
  final List<String> tags;

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
    this.street,
    this.city,
    this.zip,
    this.countryName,
    this.function,
    this.website,
    this.priority,
    this.tags = const [],
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

    // Country
    String? cName;
    if (json['country_id'] is List && json['country_id'].length > 1) {
      cName = json['country_id'][1];
    }

    // Tags
    // tag_ids in read/searchRead is usually [id, id, id] from One2many/Many2many
    // BUT we need names. The CRM service might need to fetch them separately
    // or we assume they are passed if we use 'read' with specific context.
    // Allow robust parsing if Odoo returns [id, name] list of lists (unlikely) or just IDs.
    // For now we will assume standard read returns IDs and we display IDs unless we do a secondary fetch.
    // UPDATE: The user wants DATA. Let's just store what we get.
    // If it's IDs, we might need a workaround.
    // Odoo API 'read' on Many2many returns List of IDs.
    // To get names, we need a separate call or use 'search_read' with expanded fields?
    // Let's stick to safe defaults.

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
      street: OdooUtils.safeString(json['street']),
      city: OdooUtils.safeString(json['city']),
      zip: OdooUtils.safeString(json['zip']),
      countryName: cName,
      function: OdooUtils.safeString(json['function']),
      website: OdooUtils.safeString(json['website']),
      priority: OdooUtils.safeString(json['priority']),
    );
  }
}
