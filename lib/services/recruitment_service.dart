import 'package:flutter/foundation.dart';
import '../models/recruitment_models.dart';
import 'odoo_service.dart';

class RecruitmentService {
  static final RecruitmentService _instance = RecruitmentService._internal();
  factory RecruitmentService() => _instance;
  RecruitmentService._internal();

  static const String _applicantModel = 'hr.applicant';
  static const String _stageModel = 'hr.recruitment.stage';

  Future<List<Applicant>> getApplicants({
    List<dynamic>? domain,
    int limit = 200,
  }) async {
    try {
      final odoo = OdooService.instance;

      // Phase 1: Try with all desired fields
      final fullFields = [
        'id',
        'partner_name',
        'email_from',
        'partner_phone',
        'partner_mobile',
        'job_id',
        'stage_id',
        'priority',
        'create_date',
        'attachment_number',
        'color',
      ];

      try {
        final response = await odoo.callKw(
          model: _applicantModel,
          method: 'search_read',
          args: [domain ?? []],
          kwargs: {'fields': fullFields, 'limit': limit, 'order': 'id desc'},
        );
        if (response != null && response is List) {
          debugPrint(
            'Fetched ${response.length} applicants for domain: $domain (full fields)',
          );
          final applicants = <Applicant>[];
          for (var item in response) {
            try {
              applicants.add(Applicant.fromJson(item));
            } catch (e) {
              debugPrint('Error parsing applicant ${item['id']}: $e');
            }
          }
          return applicants;
        }
      } catch (e) {
        debugPrint(
          'Full-field applicant fetch failed: $e — retrying with minimal fields',
        );
      }

      // Phase 2: Fallback — minimal fields that are guaranteed to exist
      const minimalFields = [
        'id',
        'partner_name',
        'email_from',
        'partner_phone',
        'job_id',
        'stage_id',
        'priority',
        'color',
      ];

      final fallbackResponse = await odoo.callKw(
        model: _applicantModel,
        method: 'search_read',
        args: [domain ?? []],
        kwargs: {'fields': minimalFields, 'limit': limit, 'order': 'id desc'},
      );

      if (fallbackResponse != null && fallbackResponse is List) {
        debugPrint(
          'Fetched ${fallbackResponse.length} applicants for domain: $domain (minimal fields)',
        );
        final applicants = <Applicant>[];
        for (var item in fallbackResponse) {
          try {
            applicants.add(Applicant.fromJson(item));
          } catch (e) {
            debugPrint('Error parsing applicant (fallback) ${item['id']}: $e');
          }
        }
        return applicants;
      }

      return [];
    } catch (e) {
      debugPrint('Error fetching applicants: $e');
      return [];
    }
  }

  Future<List<RecruitmentStage>> getStages({int? jobId}) async {
    try {
      final odoo = OdooService.instance;

      // Check if job_ids field exists (Odoo 17+ or custom)
      final hasJobIds = await odoo.fieldExists(
        model: _stageModel,
        fieldName: 'job_ids',
      );

      final List<dynamic> domain = [];
      if (hasJobIds && jobId != null) {
        domain.add('|');
        domain.add(['job_ids', '=', false]);
        domain.add([
          'job_ids',
          'in',
          [jobId],
        ]); // Filter specifically for this job's stages or global stages
      }

      final response = await odoo.callKw(
        model: _stageModel,
        method: 'search_read',
        args: [domain],
        kwargs: {
          'fields': ['id', 'name', 'sequence'],
          'order': 'sequence asc',
        },
      );

      if (response != null && response is List) {
        return response.map((json) => RecruitmentStage.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching recruitment stages: $e');
      rethrow; // Propagation for UI handling
    }
  }

  Future<int?> createApplicant(Map<String, dynamic> vals) async {
    try {
      final response = await OdooService.instance.callKw(
        model: _applicantModel,
        method: 'create',
        args: [vals],
      );
      if (response is int) return response;
      return null;
    } catch (e) {
      debugPrint('Error creating applicant: $e');
      rethrow;
    }
  }

  Future<bool> updateApplicant(int id, Map<String, dynamic> vals) async {
    try {
      final response = await OdooService.instance.callKw(
        model: _applicantModel,
        method: 'write',
        args: [
          [id],
          vals,
        ],
      );
      return response == true;
    } catch (e) {
      debugPrint('Error updating applicant: $e');
      return false;
    }
  }
}
