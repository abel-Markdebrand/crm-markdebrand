import '../utils/odoo_utils.dart';

class Applicant {
  final int id;
  final String name; // Subject
  final String? partnerName; // Candidate name
  final String? emailFrom;
  final String? partnerPhone;
  final String? partnerMobile;
  final int? jobId;
  final String? jobName;
  final int? stageId;
  final String? stageName;
  final String? priority;
  final String? description;
  final String? createDate;
  final int attachmentNumber;
  final int? color;

  Applicant({
    required this.id,
    required this.name,
    this.partnerName,
    this.emailFrom,
    this.partnerPhone,
    this.partnerMobile,
    this.jobId,
    this.jobName,
    this.stageId,
    this.stageName,
    this.priority,
    this.description,
    this.createDate,
    this.attachmentNumber = 0,
    this.color,
  });

  factory Applicant.fromJson(Map<String, dynamic> json) {
    int? jId;
    String? jName;
    if (json['job_id'] is List && (json['job_id'] as List).isNotEmpty) {
      jId = OdooUtils.safeInt(json['job_id'][0]);
      if ((json['job_id'] as List).length > 1) {
        jName = OdooUtils.safeString(json['job_id'][1]);
      }
    } else if (json['job_id'] is int) {
      jId = json['job_id'] as int;
    }

    int? sId;
    String? sName;
    if (json['stage_id'] is List && (json['stage_id'] as List).isNotEmpty) {
      sId = OdooUtils.safeInt(json['stage_id'][0]);
      if ((json['stage_id'] as List).length > 1) {
        sName = OdooUtils.safeString(json['stage_id'][1]);
      }
    } else if (json['stage_id'] is int) {
      sId = json['stage_id'] as int;
    }

    return Applicant(
      // Blindaje del ID principal
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: OdooUtils.safeString(json['partner_name']),
      partnerName: OdooUtils.safeString(json['partner_name']),
      emailFrom: OdooUtils.safeString(json['email_from']),
      partnerPhone: OdooUtils.safeString(json['partner_phone']),
      partnerMobile: OdooUtils.safeString(json['partner_mobile']),
      jobId: jId,
      jobName: jName,
      stageId: sId,
      stageName: sName,
      priority: OdooUtils.safeString(json['priority']),
      description: OdooUtils.safeString(json['description']),
      createDate: OdooUtils.safeString(json['create_date']),
      attachmentNumber: json['attachment_number'] is int
          ? json['attachment_number']
          : 0,
      color: json['color'] is int ? json['color'] : null,
    );
  }
}

class RecruitmentStage {
  final int id;
  final String name;

  RecruitmentStage({required this.id, required this.name});

  factory RecruitmentStage.fromJson(Map<String, dynamic> json) {
    return RecruitmentStage(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: OdooUtils.safeString(json['name']),
    );
  }
}
