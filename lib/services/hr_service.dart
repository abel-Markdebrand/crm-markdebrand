import 'package:flutter/foundation.dart';
import '../models/hr_models.dart';
import 'odoo_service.dart';

class HRService {
  static final HRService _instance = HRService._internal();
  factory HRService() => _instance;
  HRService._internal();

  static const String _employeeModel = 'hr.employee';
  static const String _jobModel = 'hr.job';
  static const String _departmentModel = 'hr.department';

  Future<List<Employee>> getEmployees({
    List<dynamic>? domain,
    int limit = 80,
  }) async {
    try {
      final odoo = OdooService.instance;

      final allRequestedFields = [
        'id',
        'name',
        'work_email',
        'mobile_phone',
        'work_phone',
        'job_title',
        'department_id',
        'image_1920',
        'parent_id',
        'coach_id',
        'country_id',
        'identification_id',
        'ssnid',
        'passport_id',
        'gender',
        'marital',
        'birthday',
        'children',
        'certificate',
        'study_field',
        'place_of_birth',
        'private_email',
        'private_phone',
        'bank_account_id',
        'visa_no',
        'permit_no',
        'visa_expire',
        'work_permit_expiration',
        'distance_home_work',
        'emergency_contact',
        'emergency_phone',
      ];

      final List<String> availableFields = [];
      final checkResults = await Future.wait(
        allRequestedFields.map(
          (field) => odoo.fieldExists(model: _employeeModel, fieldName: field),
        ),
      );

      for (int i = 0; i < allRequestedFields.length; i++) {
        if (checkResults[i]) {
          availableFields.add(allRequestedFields[i]);
        }
      }

      final response = await odoo.callKw(
        model: _employeeModel,
        method: 'search_read',
        args: [domain ?? []],
        kwargs: {
          'fields': availableFields,
          'limit': limit,
          'order': 'name asc',
        },
      );

      if (response != null && response is List) {
        return response.map((json) => Employee.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching employees: $e");
      return [];
    }
  }

  Future<List<JobPosition>> getJobPositions() async {
    try {
      final odoo = OdooService.instance;

      final allRequestedFields = [
        'id',
        'name',
        'description',
        'expected_employees',
        'department_id',
        'user_id',
        'no_of_recruitment',
        'no_of_hired_employee',
        'state',
        'alias_name',
        'is_published',
        'address_id',
        'interviewer_ids',
        'website_url',
        'application_count',
        'new_application_count',
        'employment_type_id',
        'degree_id',
      ];

      final List<String> availableFields = [];
      final checkResults = await Future.wait(
        allRequestedFields.map(
          (field) => odoo.fieldExists(model: _jobModel, fieldName: field),
        ),
      );

      for (int i = 0; i < allRequestedFields.length; i++) {
        if (checkResults[i]) {
          availableFields.add(allRequestedFields[i]);
        }
      }

      final response = await odoo.callKw(
        model: _jobModel,
        method: 'search_read',
        args: [[]],
        kwargs: {'fields': availableFields, 'order': 'name asc'},
      );

      if (response != null && response is List) {
        return response.map((json) => JobPosition.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching job positions: $e");
      return [];
    }
  }

  Future<int?> createJobPosition(Map<String, dynamic> vals) async {
    try {
      final response = await OdooService.instance.callKw(
        model: _jobModel,
        method: 'create',
        args: [vals],
      );
      if (response is int) return response;
      return null;
    } catch (e) {
      debugPrint("Error creating job position: $e");
      rethrow;
    }
  }

  Future<bool> updateJobPosition(int id, Map<String, dynamic> vals) async {
    try {
      final response = await OdooService.instance.callKw(
        model: _jobModel,
        method: 'write',
        args: [
          [id],
          vals,
        ],
      );
      return response == true;
    } catch (e) {
      debugPrint("Error updating job position: $e");
      return false;
    }
  }

  Future<List<Department>> getDepartments() async {
    try {
      final response = await OdooService.instance.callKw(
        model: _departmentModel,
        method: 'search_read',
        args: [[]],
        kwargs: {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      );

      if (response != null && response is List) {
        return response.map((json) => Department.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching departments: $e");
      return [];
    }
  }

  Future<int?> createEmployee(Map<String, dynamic> vals) async {
    try {
      final response = await OdooService.instance.callKw(
        model: _employeeModel,
        method: 'create',
        args: [vals],
      );
      if (response is int) return response;
      return null;
    } catch (e) {
      debugPrint("Error creating employee: $e");
      rethrow;
    }
  }

  Future<bool> updateEmployee(int id, Map<String, dynamic> vals) async {
    try {
      final response = await OdooService.instance.callKw(
        model: _employeeModel,
        method: 'write',
        args: [
          [id],
          vals,
        ],
      );
      return response == true;
    } catch (e) {
      debugPrint("Error updating employee: $e");
      return false;
    }
  }

  // --- Resume Lines (Currículum) ---

  Future<List<ResumeLine>> getResumeLines(int employeeId) async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'hr.resume.line',
        method: 'search_read',
        args: [
          [
            ['employee_id', '=', employeeId],
          ],
        ],
        kwargs: {
          'fields': [
            'id',
            'employee_id',
            'name',
            'date_start',
            'date_end',
            'description',
            'line_type_id',
          ],
          'order': 'date_start desc',
        },
      );

      if (response != null && response is List) {
        return response.map((json) => ResumeLine.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching resume lines: $e");
      return [];
    }
  }

  Future<List<ResumeLineType>> getResumeLineTypes() async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'hr.resume.line.type',
        method: 'search_read',
        args: [[]],
        kwargs: {
          'fields': ['id', 'name'],
          'order': 'sequence asc, id asc',
        },
      );

      if (response != null && response is List) {
        return response.map((json) => ResumeLineType.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching resume line types: $e");
      return [];
    }
  }

  Future<bool> createResumeLine(Map<String, dynamic> vals) async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'hr.resume.line',
        method: 'create',
        args: [vals],
      );
      return response is int;
    } catch (e) {
      debugPrint("Error creating resume line: $e");
      return false;
    }
  }

  Future<bool> deleteResumeLine(int id) async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'hr.resume.line',
        method: 'unlink',
        args: [
          [id],
        ],
      );
      return response == true;
    } catch (e) {
      debugPrint("Error deleting resume line: $e");
      return false;
    }
  }

  // --- Employee Contracts (using hr.version as found on server) ---

  /// Search for the most recent hr.version id for an employee.
  /// Uses only 'id' field to avoid any invalid-field errors on this server.
  Future<int?> _findVersionId(int employeeId) async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'hr.version',
        method: 'search_read',
        args: [
          [
            ['employee_id', '=', employeeId],
          ],
        ],
        kwargs: {
          'fields': ['id'],
          'limit': 1,
          'order': 'id desc',
        },
      );
      if (response is List && response.isNotEmpty) {
        final raw = response[0];
        if (raw is Map && raw['id'] is int) return raw['id'] as int;
      }
      return null;
    } catch (e) {
      debugPrint("_findVersionId error: $e");
      return null;
    }
  }

  Future<Contract?> getContract(int employeeId) async {
    final versionId = await _findVersionId(employeeId);
    if (versionId == null) return null;

    final fields = [
      'id',
      'name',
      'wage',
      'date_start',
      'date_end',
      'contract_type_id',
      'structure_type_id',
      'resource_calendar_id',
    ];

    try {
      final response = await OdooService.instance.callKw(
        model: 'hr.version',
        method: 'read',
        args: [
          [versionId],
        ],
        kwargs: {'fields': fields},
      );
      if (response is List && response.isNotEmpty) {
        return Contract.fromJson(response[0]);
      }
    } catch (e) {
      debugPrint("getContract read error: $e – returning id-only stub");
    }
    // Fallback: return a minimal Contract so the caller knows it exists
    return Contract(id: versionId, name: '', wage: 0);
  }

  Future<int?> createContract(Map<String, dynamic> vals) async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'hr.version',
        method: 'create',
        args: [vals],
      );
      if (response is int) return response;
      return null;
    } catch (e) {
      debugPrint("Error creating contract (hr.version): $e");
      rethrow;
    }
  }

  Future<bool> updateContract(int id, Map<String, dynamic> vals) async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'hr.version',
        method: 'write',
        args: [
          [id],
          vals,
        ],
      );
      return response == true;
    } catch (e) {
      debugPrint("Error updating contract (hr.version): $e");
      rethrow;
    }
  }

  /// Upsert: find existing version → update, or create new.
  /// If create throws a uniqueness conflict, retries find + update.
  Future<void> upsertContract(int employeeId, Map<String, dynamic> vals) async {
    int? existingId = await _findVersionId(employeeId);

    if (existingId != null) {
      debugPrint("upsertContract: version $existingId found → updating");
      await updateContract(existingId, vals);
      return;
    }

    try {
      debugPrint("upsertContract: no version found → creating");
      await createContract(vals);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already exists') ||
          msg.contains('unique') ||
          msg.contains('duplicate') ||
          msg.contains('version')) {
        debugPrint(
          "upsertContract: conflict on create, re-querying for update",
        );
        final retryId = await _findVersionId(employeeId);
        if (retryId != null) {
          await updateContract(retryId, vals);
          return;
        }
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getContractTypes() async {
    try {
      // We'll try hr.contract.type first, as it might still exist even if hr.contract doesn't
      final response = await OdooService.instance
          .callKw(
            model:
                'hr_contract_type', // Re-trying this name or hr.contract.type
            method: 'search_read',
            args: [[]],
            kwargs: {
              'fields': ['id', 'name'],
            },
          )
          .catchError(
            (_) => OdooService.instance.callKw(
              model: 'hr.contract.type',
              method: 'search_read',
              args: [[]],
              kwargs: {
                'fields': ['id', 'name'],
              },
            ),
          );

      if (response is List) return response.cast<Map<String, dynamic>>();
      return [];
    } catch (e) {
      debugPrint("Error fetching contract types: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getStructureTypes() async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'hr.payroll.structure.type',
        method: 'search_read',
        args: [[]],
        kwargs: {
          'fields': ['id', 'name'],
        },
      );
      if (response is List) return response.cast<Map<String, dynamic>>();
      return [];
    } catch (e) {
      debugPrint("Error fetching structure types: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getWorkingHours() async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'resource.calendar',
        method: 'search_read',
        args: [[]],
        kwargs: {
          'fields': ['id', 'name'],
        },
      );
      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching working hours: $e");
      return [];
    }
  }
}
