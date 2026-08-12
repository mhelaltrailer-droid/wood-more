import '../models/user_model.dart';

/// التسمية العربية للدور كما تُعرض للمستخدم.
String arabicRoleLabel(String role) {
  switch (role.trim()) {
    case 'site_engineer':
      return 'مهندس موقع';
    case 'site_engineer_manager':
      return UserModel.siteEngineerManagerRoleLabel;
    case 'general_supervisor':
      return UserModel.generalSupervisorRoleLabel;
    case 'operation_manager':
      return 'مدير العمليات';
    case 'accountant':
      return 'المحاسب';
    case 'document_controller':
      return UserModel.documentControllerRoleLabel;
    case 'technical_office':
      return UserModel.technicalOfficeRoleLabel;
    case 'top_management':
      return UserModel.topManagementRoleLabel;
    case 'op_coordinator':
      return UserModel.opCoordinatorRoleLabel;
    case 'app_admin':
      return 'مسؤول التطبيق';
    default:
      return '';
  }
}
