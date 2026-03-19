import 'package:flutter/foundation.dart';
import 'package:mvp_odoo/services/odoo_service.dart';

class PermissionService {
  static final PermissionService instance = PermissionService._internal();

  PermissionService._internal();

  bool hasCrmAccess = false;
  bool hasSalesAccess = false;
  bool hasContactsAccess = false;
  bool hasProjectAccess = false;
  bool hasTimesheetAccess = false;
  bool hasAttendanceAccess = false;
  bool hasDiscussAccess = false;
  bool hasInventoryAccess = false;
  bool hasHrAccess = false;
  bool hasRecruitmentAccess = false;

  bool _isInitialized = false;

  Future<void> fetchPermissions({bool force = false}) async {
    if (_isInitialized && !force) return;

    // Default assume they have discuss/messaging and contacts
    hasDiscussAccess = true;
    hasContactsAccess = true;
    hasHrAccess = false; // Disabled per user request due to failures

    bool mailChannelOk = false;
    bool discussChannelOk = false;

    // Call check_access_rights ('read') for all required models in parallel
    // to avoid slowing down the dashboard login sequence.
    final models = {
      'crm.lead': (bool res) => hasCrmAccess = res,
      'sale.order': (bool res) => hasSalesAccess = res,
      'res.partner': (bool res) => hasContactsAccess = res,
      'project.project': (bool res) => hasProjectAccess = res,
      'account.analytic.line': (bool res) => hasTimesheetAccess = res,
      'hr.attendance': (bool res) => hasAttendanceAccess = res,
      'product.template': (bool res) => hasInventoryAccess = res,
      'hr.employee': (bool res) => hasHrAccess = res,
      'hr.applicant': (bool res) => hasRecruitmentAccess = res,
      'mail.channel': (bool res) => mailChannelOk = res, // For odoo <= 16
      'discuss.channel': (bool res) => discussChannelOk = res, // For odoo >= 17
    };

    final futures = <Future<void>>[];

    for (var model in models.keys) {
      futures.add(
        OdooService.instance
            .callKw(
              model: model,
              method: 'search_count',
              args: [[]],
              kwargs: {},
            )
            .then((res) {
              // If search_count returns an integer (even 0), the user has read access to the model
              if (res is int) {
                models[model]!(true);
              }
            })
            .catchError((e) {
              // If the model doesn't exist or access is denied, search_count throws an error
              debugPrint("🚫 PermissionService: No access to $model ($e)");
              models[model]!(false);
            }),
      );
    }

    await Future.wait(futures);

    // Evaluate Discuss Access after both versions are checked
    hasDiscussAccess = mailChannelOk || discussChannelOk;

    _isInitialized = true;
    debugPrint("✅ PermissionService: Loaded user access rights.");
    debugPrint(" - CRM: $hasCrmAccess");
    debugPrint(" - Sales: $hasSalesAccess");
    debugPrint(" - Contacts: $hasContactsAccess");
    debugPrint(" - Projects: $hasProjectAccess");
    debugPrint(" - Timesheets: $hasTimesheetAccess");
    debugPrint(" - Attendance: $hasAttendanceAccess");
    debugPrint(" - Inventory: $hasInventoryAccess");
    debugPrint(" - HR (Employees): $hasHrAccess");
    debugPrint(" - Recruitment: $hasRecruitmentAccess");
    debugPrint(" - Discuss: $hasDiscussAccess");
  }
}
