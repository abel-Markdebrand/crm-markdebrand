import '../utils/odoo_utils.dart';

class Partner {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? vat;

  Partner({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.vat,
  });

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      id: json['id'] as int,
      name: OdooUtils.safeString(json['name']) == ''
          ? 'Unknown'
          : OdooUtils.safeString(json['name']),
      email: OdooUtils.safeString(json['email']),
      phone: OdooUtils.safeString(json['phone']),
      vat: OdooUtils.safeString(json['vat']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'phone': phone, 'vat': vat};
  }
}
