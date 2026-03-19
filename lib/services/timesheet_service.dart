import 'package:flutter/foundation.dart';
import 'package:mvp_odoo/services/odoo_service.dart';

class TimesheetService {
  static final TimesheetService _instance = TimesheetService._internal();
  factory TimesheetService() => _instance;
  TimesheetService._internal();

  static const String _model = 'account.analytic.line';

  /// Fetch timesheets for the current user
  /// Returns a list of maps, where each map represents a timesheet entry.
  Future<List<Map<String, dynamic>>> getTimesheets({int limit = 20}) async {
    try {
      final uid = OdooService.instance.uid;
      if (uid == null) throw Exception("User not logged in");

      // Define the domain to filter timesheets for the current user
      final domain = [
        ['user_id', '=', uid],
      ];

      // Fields to fetch
      final fields = [
        'id',
        'date',
        'project_id',
        'task_id',
        'name',
        'unit_amount',
      ];

      final response = await OdooService.instance.callKw(
        model: _model,
        method: 'search_read',
        args: [domain],
        kwargs: {
          'fields': fields,
          'limit': limit,
          'order': 'date desc, id desc',
        },
      );

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching timesheets: $e");
      rethrow;
    }
  }

  /// Create a new timesheet entry
  Future<int> createTimesheet({
    required int projectId,
    required double hours,
    required String date,
    String? description,
    int? taskId,
  }) async {
    try {
      final uid = OdooService.instance.uid;
      if (uid == null) throw Exception("User not logged in");

      final values = {
        'project_id': projectId,
        'unit_amount': hours,
        'date': date,
        'name': description ?? '',
        'user_id': uid,
      };

      if (taskId != null) {
        values['task_id'] = taskId;
      }

      final response = await OdooService.instance.callKw(
        model: _model,
        method: 'create',
        args: [values],
      );

      return response is int ? response : response[0];
    } catch (e) {
      debugPrint("Error creating timesheet: $e");
      rethrow;
    }
  }

  /// Update an existing timesheet entry
  Future<void> updateTimesheet({
    required int id,
    int? projectId,
    double? hours,
    String? date,
    String? description,
    int? taskId,
  }) async {
    try {
      final values = <String, dynamic>{};
      if (projectId != null) values['project_id'] = projectId;
      if (hours != null) values['unit_amount'] = hours;
      if (date != null) values['date'] = date;
      if (description != null) values['name'] = description;
      if (taskId != null) values['task_id'] = taskId;

      if (values.isEmpty) return;

      await OdooService.instance.callKw(
        model: _model,
        method: 'write',
        args: [
          [id],
          values,
        ],
      );
    } catch (e) {
      debugPrint("Error updating timesheet: $e");
      rethrow;
    }
  }

  /// Delete a timesheet entry
  Future<void> deleteTimesheet(int id) async {
    try {
      await OdooService.instance.callKw(
        model: _model,
        method: 'unlink',
        args: [
          [id],
        ],
      );
    } catch (e) {
      debugPrint("Error deleting timesheet: $e");
      rethrow;
    }
  }

  /// Fetch available projects
  /// Returns a list of maps with 'id' and 'name'
  Future<List<Map<String, dynamic>>> getProjects() async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'project.project',
        method: 'search_read',
        args: [
          [], // Empty domain to fetch all active projects (or filter as needed)
        ],
        kwargs: {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching projects: $e");
      // Return empty list instead of throwing to allow UI to handle gracefully
      return [];
    }
  }

  /// Fetch tasks for a specific project
  Future<List<Map<String, dynamic>>> getTasks(int projectId) async {
    try {
      final domain = [
        ['project_id', '=', projectId],
      ];

      final response = await OdooService.instance.callKw(
        model: 'project.task',
        method: 'search_read',
        args: [domain],
        kwargs: {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching tasks: $e");
      return [];
    }
  }
}
