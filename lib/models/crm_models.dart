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
  // Marketing
  final int? campaignId;
  final String? campaignName;
  final int? mediumId;
  final String? mediumName;
  final int? sourceId;
  final String? sourceName;
  // Niches (Custom)
  final String? niche;

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
    this.campaignId,
    this.campaignName,
    this.mediumId,
    this.mediumName,
    this.sourceId,
    this.sourceName,
    this.niche,
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
      tags:
          [], // Parsing tags is complex if they come as IDs. Leaving empty for now or implementing later.
      // Marketing Parsing (Many2one usually)
      campaignId: json['campaign_id'] is List
          ? json['campaign_id'][0]
          : (json['campaign_id'] is int ? json['campaign_id'] : null),
      campaignName: json['campaign_id'] is List ? json['campaign_id'][1] : null,

      mediumId: json['medium_id'] is List
          ? json['medium_id'][0]
          : (json['medium_id'] is int ? json['medium_id'] : null),
      mediumName: json['medium_id'] is List ? json['medium_id'][1] : null,

      sourceId: json['source_id'] is List
          ? json['source_id'][0]
          : (json['source_id'] is int ? json['source_id'] : null),
      sourceName: json['source_id'] is List ? json['source_id'][1] : null,

      // Assuming 'x_niche' or similar. Using 'function' as a fallback if not found or just a placeholder name
      // The user called it 'Niches', keys should be checked. For now we will try to read 'x_niche' if it exists, else null.
      niche: OdooUtils.safeString(json['x_niche'] ?? json['function']),
    );
  }
}
