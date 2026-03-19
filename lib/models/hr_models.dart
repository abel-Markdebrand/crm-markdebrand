import '../utils/odoo_utils.dart';

class Employee {
  final int id;
  final String name;
  final String? workEmail;
  final String? mobilePhone;
  final String? workPhone;
  final String? jobTitle;
  final int? departmentId;
  final String? departmentName;
  final String? image1920;
  final int? parentId; // Manager
  final String? parentName;
  final int? coachId;
  final String? coachName;

  // Personal Information
  final String? nationality;
  final int? countryId;
  final String? identificationId;
  final String? ssnid;
  final String? passportId;
  final String? gender; // 'male', 'female', 'other'
  final String?
  marital; // 'single', 'married', 'cohabitant', 'widower', 'divorced'
  final String? birthday;
  final int? children;
  final String?
  certificate; // 'graduate', 'bachelor', 'master', 'doctor', 'other'
  final String? studyField;
  final String? placeOfBirth;

  // Private Information
  final String? privateEmail;
  final String? privatePhone;
  final double? distanceHomeWork;
  final String? emergencyContact;
  final String? emergencyPhone;
  final String? bankAccount; // bank_account_id name

  // Work Permit
  final String? visaNo;
  final String? permitNo;
  final String? visaExpire;
  final String? workPermitExpiration;

  Employee({
    required this.id,
    required this.name,
    this.workEmail,
    this.mobilePhone,
    this.workPhone,
    this.jobTitle,
    this.departmentId,
    this.departmentName,
    this.image1920,
    this.parentId,
    this.parentName,
    this.coachId,
    this.coachName,
    this.nationality,
    this.countryId,
    this.identificationId,
    this.ssnid,
    this.passportId,
    this.gender,
    this.marital,
    this.birthday,
    this.children,
    this.certificate,
    this.studyField,
    this.placeOfBirth,
    this.privateEmail,
    this.privatePhone,
    this.distanceHomeWork,
    this.emergencyContact,
    this.emergencyPhone,
    this.bankAccount,
    this.visaNo,
    this.permitNo,
    this.visaExpire,
    this.workPermitExpiration,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    int? deptId;
    String? deptName;
    if (json['department_id'] is List) {
      deptId = json['department_id'][0];
      deptName = json['department_id'][1];
    }

    int? mgrId;
    String? mgrName;
    if (json['parent_id'] is List) {
      mgrId = json['parent_id'][0];
      mgrName = json['parent_id'][1];
    }

    int? cchId;
    String? cchName;
    if (json['coach_id'] is List) {
      cchId = json['coach_id'][0];
      cchName = json['coach_id'][1];
    }

    int? cntId;
    String? cntName;
    if (json['country_id'] is List) {
      cntId = json['country_id'][0];
      cntName = json['country_id'][1];
    }

    String? bAccount;
    if (json['bank_account_id'] is List) {
      bAccount = json['bank_account_id'][1];
    }

    return Employee(
      id: json['id'],
      name: OdooUtils.safeString(json['name']),
      workEmail: OdooUtils.safeString(json['work_email']),
      mobilePhone: OdooUtils.safeString(json['mobile_phone']),
      workPhone: OdooUtils.safeString(json['work_phone']),
      jobTitle: OdooUtils.safeString(json['job_title']),
      departmentId: deptId,
      departmentName: deptName,
      image1920: OdooUtils.safeString(json['image_1920']),
      parentId: mgrId,
      parentName: mgrName,
      coachId: cchId,
      coachName: cchName,
      nationality: cntName,
      countryId: cntId,
      identificationId: OdooUtils.safeString(json['identification_id']),
      ssnid: OdooUtils.safeString(json['ssnid']),
      passportId: OdooUtils.safeString(json['passport_id']),
      gender: OdooUtils.safeString(json['gender']),
      marital: OdooUtils.safeString(json['marital']),
      birthday: OdooUtils.safeString(json['birthday']),
      children: json['children'] is int ? json['children'] : 0,
      certificate: OdooUtils.safeString(json['certificate']),
      studyField: OdooUtils.safeString(json['study_field']),
      placeOfBirth: OdooUtils.safeString(json['place_of_birth']),
      privateEmail: OdooUtils.safeString(json['private_email']),
      privatePhone: OdooUtils.safeString(json['private_phone']),
      distanceHomeWork: (json['distance_home_work'] as num?)?.toDouble(),
      emergencyContact: OdooUtils.safeString(json['emergency_contact']),
      emergencyPhone: OdooUtils.safeString(json['emergency_phone']),
      bankAccount: bAccount,
      visaNo: OdooUtils.safeString(json['visa_no']),
      permitNo: OdooUtils.safeString(json['permit_no']),
      visaExpire: OdooUtils.safeString(json['visa_expire']),
      workPermitExpiration: OdooUtils.safeString(
        json['work_permit_expiration'],
      ),
    );
  }
}

class JobPosition {
  final int id;
  final String name;
  final String? description;
  final int? expectedEmployees;
  final int? departmentId;
  final String? departmentName;
  final int? userId; // Recruiter
  final String? userName; // Recruiter Name
  final int? noOfRecruitment; // In progress
  final int? noOfHiredEmployee; // Hired
  final int? state; // 1 = Recruiting, 0 = Not Recruiting (open/closed)
  final String? aliasName; // typically alias_email or alias_name
  final bool isPublished;
  final int? addressId;
  final String? addressName;
  final List<int> interviewerIds;
  final String? websiteUrl;
  final int? applicationCount;
  final int? newApplicationCount;
  final String? employmentTypeName;
  final String? degreeName;

  JobPosition({
    required this.id,
    required this.name,
    this.description,
    this.expectedEmployees,
    this.departmentId,
    this.departmentName,
    this.userId,
    this.userName,
    this.noOfRecruitment,
    this.noOfHiredEmployee,
    this.state,
    this.aliasName,
    this.isPublished = false,
    this.addressId,
    this.addressName,
    this.interviewerIds = const [],
    this.websiteUrl,
    this.applicationCount,
    this.newApplicationCount,
    this.employmentTypeName,
    this.degreeName,
  });

  factory JobPosition.fromJson(Map<String, dynamic> json) {
    int? deptId;
    String? deptName;
    if (json['department_id'] is List && json['department_id'].isNotEmpty) {
      deptId = json['department_id'][0];
      deptName = json['department_id'][1];
    }

    int? uId;
    String? uName;
    if (json['user_id'] is List && json['user_id'].isNotEmpty) {
      uId = json['user_id'][0];
      uName = json['user_id'][1];
    }

    int? aId;
    String? aName;
    if (json['address_id'] is List && json['address_id'].isNotEmpty) {
      aId = json['address_id'][0];
      aName = json['address_id'][1];
    }

    List<int> intIds = [];
    if (json['interviewer_ids'] is List) {
      intIds = (json['interviewer_ids'] as List).map((e) => e as int).toList();
    }

    String aliasTemp = OdooUtils.safeString(json['alias_name']);
    if (aliasTemp.isEmpty) {
      aliasTemp = OdooUtils.safeString(json['alias_email']);
    }

    String? empTypeName;
    if (json['employment_type_id'] is List) {
      empTypeName = json['employment_type_id'][1];
    }

    String? degName;
    if (json['degree_id'] is List) {
      degName = json['degree_id'][1];
    }

    return JobPosition(
      id: json['id'] is int ? json['id'] : 0,
      name: OdooUtils.safeString(json['name']),
      description: OdooUtils.safeString(json['description']),
      expectedEmployees: json['expected_employees'] is int
          ? json['expected_employees']
          : 0,
      departmentId: deptId,
      departmentName: deptName,
      userId: uId,
      userName: uName,
      noOfRecruitment: json['no_of_recruitment'] is int
          ? json['no_of_recruitment']
          : 0,
      noOfHiredEmployee: json['no_of_hired_employee'] is int
          ? json['no_of_hired_employee']
          : 0,
      state: json['state'] == 'recruit' ? 1 : 0,
      aliasName: aliasTemp,
      isPublished: json['is_published'] == true,
      addressId: aId,
      addressName: aName,
      interviewerIds: intIds,
      websiteUrl: OdooUtils.safeString(json['website_url']),
      applicationCount: json['application_count'] is int
          ? json['application_count']
          : 0,
      newApplicationCount: json['new_application_count'] is int
          ? json['new_application_count']
          : 0,
      employmentTypeName: empTypeName,
      degreeName: degName,
    );
  }
}

class Department {
  final int id;
  final String name;

  Department({required this.id, required this.name});

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(id: json['id'], name: OdooUtils.safeString(json['name']));
  }
}

class ResumeLineType {
  final int id;
  final String name;

  ResumeLineType({required this.id, required this.name});

  factory ResumeLineType.fromJson(Map<String, dynamic> json) {
    return ResumeLineType(
      id: json['id'],
      name: OdooUtils.safeString(json['name']),
    );
  }
}

class ResumeLine {
  final int id;
  final int employeeId;
  final String name;
  final String? dateStart;
  final String? dateEnd;
  final String? description;
  final int? lineTypeId;
  final String? lineTypeName;

  ResumeLine({
    required this.id,
    required this.employeeId,
    required this.name,
    this.dateStart,
    this.dateEnd,
    this.description,
    this.lineTypeId,
    this.lineTypeName,
  });

  factory ResumeLine.fromJson(Map<String, dynamic> json) {
    int? typeId;
    String? typeName;
    if (json['line_type_id'] is List && json['line_type_id'].isNotEmpty) {
      typeId = json['line_type_id'][0];
      typeName = json['line_type_id'][1];
    }

    int empId = 0;
    if (json['employee_id'] is List && json['employee_id'].isNotEmpty) {
      empId = json['employee_id'][0];
    } else if (json['employee_id'] is int) {
      empId = json['employee_id'];
    }

    return ResumeLine(
      id: json['id'],
      employeeId: empId,
      name: OdooUtils.safeString(json['name']),
      dateStart: OdooUtils.safeString(json['date_start']),
      dateEnd: OdooUtils.safeString(json['date_end']),
      description: OdooUtils.safeString(json['description']),
      lineTypeId: typeId,
      lineTypeName: typeName,
    );
  }
}

class Contract {
  final int id;
  final String name;
  final double wage;
  final String? state;
  final int? contractTypeId;
  final String? contractTypeName;
  final int? employeeTypeId;
  final String? employeeTypeName;
  final int? payCategoryId;
  final String? payCategoryName;
  final int? workingHoursId;
  final String? workingHoursName;
  final String? dateStart;
  final String? dateEnd;

  Contract({
    required this.id,
    required this.name,
    this.wage = 0.0,
    this.state,
    this.contractTypeId,
    this.contractTypeName,
    this.employeeTypeId,
    this.employeeTypeName,
    this.payCategoryId,
    this.payCategoryName,
    this.workingHoursId,
    this.workingHoursName,
    this.dateStart,
    this.dateEnd,
  });

  factory Contract.fromJson(Map<String, dynamic> json) {
    int? typeId;
    String? typeName;
    if (json['contract_type_id'] is List &&
        json['contract_type_id'].isNotEmpty) {
      typeId = json['contract_type_id'][0];
      typeName = json['contract_type_id'][1];
    }

    int? empTypeId;
    String? empTypeName;
    if (json['employee_type_id'] is List &&
        json['employee_type_id'].isNotEmpty) {
      empTypeId = json['employee_type_id'][0];
      empTypeName = json['employee_type_id'][1];
    }

    int? payCatId;
    String? payCatName;
    // Handled both pay_category_id (standard) and potentially field mapping
    final payCatField = json['pay_category_id'] ?? json['structure_type_id'];
    if (payCatField is List && payCatField.isNotEmpty) {
      payCatId = payCatField[0];
      payCatName = payCatField[1];
    } else if (json['pay_category'] is String) {
      payCatName = json['pay_category'];
    }

    int? hoursId;
    String? hoursName;
    if (json['resource_calendar_id'] is List &&
        json['resource_calendar_id'].isNotEmpty) {
      hoursId = json['resource_calendar_id'][0];
      hoursName = json['resource_calendar_id'][1];
    }

    return Contract(
      id: json['id'] is int ? json['id'] : 0,
      name: OdooUtils.safeString(json['name']),
      wage: (json['wage'] as num?)?.toDouble() ?? 0.0,
      state: OdooUtils.safeString(json['state']),
      contractTypeId: typeId,
      contractTypeName: typeName,
      employeeTypeId: empTypeId,
      employeeTypeName: empTypeName,
      payCategoryId: payCatId,
      payCategoryName: payCatName,
      workingHoursId: hoursId,
      workingHoursName: hoursName,
      dateStart: OdooUtils.safeString(json['date_start']),
      dateEnd: OdooUtils.safeString(json['date_end']),
    );
  }
}
