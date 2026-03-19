import 'package:flutter/foundation.dart';
import 'package:mvp_odoo/services/odoo_service.dart';
import 'package:intl/intl.dart';

class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();
  factory AttendanceService() => _instance;
  AttendanceService._internal();

  // User specified 'attendances' module, though standard is 'hr.attendance'.
  // We will try 'hr.attendance' first as it's the standard model name even if the module is named 'attendances'.
  // If the user meant a custom model named 'attendances', we would use that.
  // However, usually module name != model name.
  // Let's stick to 'hr.attendance' for now but add a comment.
  static const String _model = 'hr.attendance';

  /// Get the last attendance record for the current user
  /// Returns null if no record found.
  Future<Map<String, dynamic>?> getLastAttendance() async {
    try {
      final uid = OdooService.instance.uid;
      if (uid == null) throw Exception("User not logged in");

      // We need to find the employee_id associated with the user_id first
      // However, usually hr.attendance is linked to employee_id.
      // Let's try to search by employee_id.user_id = uid first or directly by employee_id if we have it.
      // A common pattern in Odoo is that hr.attendance has an 'employee_id' field.
      // We need to fetch the employee ID for the current user.

      final employeeId = await _getEmployeeId(uid);
      if (employeeId == null) return null;

      final domain = [
        ['employee_id', '=', employeeId],
      ];

      final response = await OdooService.instance.callKw(
        model: _model,
        method: 'search_read',
        args: [domain],
        kwargs: {
          'fields': ['id', 'check_in', 'check_out'],
          'limit': 1,
          'order': 'check_in desc',
        },
      );

      if (response != null && response is List && response.isNotEmpty) {
        return response[0] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching last attendance: $e");
      return null;
    }
  }

  /// Check In
  Future<void> checkIn() async {
    try {
      // Odoo often has a helper method on hr.employee or hr.attendance
      // Common method: update_attendance
      // or creating a new record manually.
      // Let's try creating a record manually first as it's more standard if no custom module.

      final uid = OdooService.instance.uid;
      if (uid == null) throw Exception("User not logged in");

      final employeeId = await _getEmployeeId(uid);
      if (employeeId == null) {
        throw Exception("Employee record not found for user");
      }
      // Check if already checked in
      final last = await getLastAttendance();
      if (last != null &&
          (last['check_out'] == false || last['check_out'] == null)) {
        throw Exception("Already checked in");
      }

      // Create new check-in
      // Dates in Odoo are UTC strings
      final now = DateTime.now().toUtc();
      final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      await OdooService.instance.callKw(
        model: _model,
        method: 'create',
        args: [
          {'employee_id': employeeId, 'check_in': dateStr},
        ],
      );
    } catch (e) {
      debugPrint("Error checking in: $e");
      rethrow;
    }
  }

  /// Check Out
  Future<void> checkOut() async {
    try {
      final uid = OdooService.instance.uid;
      if (uid == null) throw Exception("User not logged in");

      final employeeId = await _getEmployeeId(uid);
      if (employeeId == null) {
        throw Exception("Employee record not found for user");
      }

      final last = await getLastAttendance();
      if (last == null ||
          (last['check_out'] != false && last['check_out'] != null)) {
        throw Exception("Not checked in");
      }

      final now = DateTime.now().toUtc();
      final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      try {
        await OdooService.instance.callKw(
          model: _model,
          method: 'write',
          args: [
            [last['id']],
            {'check_out': dateStr},
          ],
        );
      } catch (writeError) {
        // Fallback to Odoo's native manual attendance toggler
        debugPrint("Write failed, attempting attendance_manual: $writeError");
        await OdooService.instance.callKw(
          model: 'hr.employee',
          method: 'attendance_manual',
          args: [
            [employeeId],
            'hr_attendance.hr_attendance_action_my_attendances',
          ],
        );
      }
    } catch (e) {
      debugPrint("Error checking out: $e");
      rethrow;
    }
  }

  /// Helper to get Employee ID from User ID
  Future<int?> _getEmployeeId(int uid) async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'hr.employee',
        method: 'search_read',
        args: [
          [
            ['user_id', '=', uid],
          ],
        ],
        kwargs: {
          'fields': ['id'],
          'limit': 1,
        },
      );

      if (response != null && response is List && response.isNotEmpty) {
        return response[0]['id'];
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching employee ID: $e");
      return null;
    }
  }

  /// Get attendance history with optional month/year filtering
  Future<List<Map<String, dynamic>>> getAttendances({
    int limit = 50,
    int? month,
    int? year,
  }) async {
    try {
      final uid = OdooService.instance.uid;
      if (uid == null) throw Exception("User not logged in");

      final employeeId = await _getEmployeeId(uid);
      if (employeeId == null) {
        throw Exception(
          "El usuario actual no tiene un Empleado (HR) asociado en Odoo.",
        );
      }

      final domain = [
        ['employee_id', '=', employeeId],
      ];

      if (month != null && year != null) {
        // Build range for the month
        final firstDay = DateTime(year, month, 1);
        final lastDay = DateTime(year, month + 1, 0, 23, 59, 59);

        final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
        domain.add(['check_in', '>=', formatter.format(firstDay.toUtc())]);
        domain.add(['check_in', '<=', formatter.format(lastDay.toUtc())]);
      }

      final response = await OdooService.instance.callKw(
        model: _model,
        method: 'search_read',
        args: [domain],
        kwargs: {
          'fields': [
            'id',
            'employee_id', // Added to show employee name
            'check_in',
            'check_out',
            'worked_hours',
          ],
          'limit': limit,
          'order': 'check_in desc',
        },
      );

      if (response != null && response is List) {
        // We handle missing fields by checking the keys in each record if needed,
        // but search_read usually just returns what's available or nulls.
        return List<Map<String, dynamic>>.from(response).map((record) {
          // If the server didn't provide worked_hours, calculate it if possible
          if (record['worked_hours'] == null &&
              record['check_in'] != false &&
              record['check_in'] != null &&
              record['check_out'] != false &&
              record['check_out'] != null) {
            try {
              // Ensure dates are parsed as UTC since Odoo sends UTC strings
              final checkIn = DateTime.parse(
                record['check_in'].toString() +
                    (record['check_in'].toString().endsWith('Z') ? '' : 'Z'),
              );
              final checkOut = DateTime.parse(
                record['check_out'].toString() +
                    (record['check_out'].toString().endsWith('Z') ? '' : 'Z'),
              );
              final duration = checkOut.difference(checkIn);
              record['worked_hours'] = duration.inSeconds / 3600.0;
            } catch (_) {}
          }
          return record;
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching attendances: $e");
      return [];
    }
  }
}
