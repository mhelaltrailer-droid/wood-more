import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wood_and_more_app/models/withdrawal_request_model.dart';
import 'package:wood_and_more_app/utils/withdrawal_request_action_display.dart';

WithdrawalRequestModel _request({
  String semStatus = WithdrawalRequestModel.statusPending,
  String omStatus = WithdrawalRequestModel.statusPending,
  String? semReason,
  String? omReason,
  DateTime? semRespondedAt,
  DateTime? omRespondedAt,
  String overallStatus = WithdrawalRequestModel.statusPending,
  DateTime? fulfilledAt,
}) {
  return WithdrawalRequestModel(
    id: 7,
    projectId: 1,
    locationId: 2,
    phase: 'first_fix',
    engineerUserId: 3,
    engineerUserName: 'مهندس',
    locationPathLabel: 'برج أ / دور 1',
    semStatus: semStatus,
    omStatus: omStatus,
    semReason: semReason,
    omReason: omReason,
    semRespondedAt: semRespondedAt,
    omRespondedAt: omRespondedAt,
    overallStatus: overallStatus,
    fulfilledAt: fulfilledAt,
    createdAt: DateTime.utc(2026, 8, 9, 8),
    updatedAt: DateTime.utc(2026, 8, 9, 8),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  test('الطلب الجديد بانتظار قرار مدير المشروعات فقط', () {
    final r = _request();
    expect(withdrawalIsActionableForRole(r, withdrawalRoleSem), isTrue);
    expect(withdrawalIsActionableForRole(r, withdrawalRoleOm), isFalse);
    expect(withdrawalStatusBadgeLabel(r, withdrawalRoleSem), 'بانتظار قراركم');
  });

  test('بعد موافقة مدير المشروعات يبقى الطلب ظاهراً بسطر الإجراء', () {
    final r = _request(
      semStatus: WithdrawalRequestModel.statusApproved,
      semRespondedAt: DateTime.utc(2026, 8, 9, 11),
    );
    expect(withdrawalIsActionableForRole(r, withdrawalRoleSem), isFalse);
    final line = withdrawalOwnActionLine(r, withdrawalRoleSem);
    expect(line, isNotNull);
    expect(line, startsWith('تمت الموافقة على طلب السحب بتاريخ '));
    expect(line, contains('2026'));
    expect(withdrawalIsActionableForRole(r, withdrawalRoleOm), isTrue);
  });

  test('الرفض يُظهر التاريخ والسبب', () {
    final r = _request(
      semStatus: WithdrawalRequestModel.statusRejected,
      semReason: 'الكمية غير متاحة',
      semRespondedAt: DateTime.utc(2026, 8, 9, 11),
      overallStatus: WithdrawalRequestModel.statusRejected,
    );
    final line = withdrawalOwnActionLine(r, withdrawalRoleSem);
    expect(line, startsWith('تم رفض طلب السحب بتاريخ '));
    expect(line, contains('السبب: الكمية غير متاحة'));
    expect(withdrawalStatusBadgeLabel(r, withdrawalRoleSem), 'مرفوض');
  });

  test('كل مدير يرى قرار المدير الآخر على نفس الطلب', () {
    final r = _request(
      semStatus: WithdrawalRequestModel.statusApproved,
      semRespondedAt: DateTime.utc(2026, 8, 9, 11),
      omStatus: WithdrawalRequestModel.statusApproved,
      omRespondedAt: DateTime.utc(2026, 8, 9, 12),
      overallStatus: WithdrawalRequestModel.statusApproved,
    );
    expect(
      withdrawalOtherManagerLine(r, withdrawalRoleSem),
      startsWith('تمت موافقة مدير العمليات على طلب السحب بتاريخ '),
    );
    expect(
      withdrawalOtherManagerLine(r, withdrawalRoleOm),
      startsWith('تمت موافقة مدير المشروعات على طلب السحب بتاريخ '),
    );
    expect(withdrawalStatusBadgeLabel(r, withdrawalRoleOm), 'معتمد');
  });

  test('بعد إتمام السحب تتغير الشارة ولا يعود الطلب قابلاً للإجراء', () {
    final r = _request(
      semStatus: WithdrawalRequestModel.statusApproved,
      semRespondedAt: DateTime.utc(2026, 8, 9, 11),
      omStatus: WithdrawalRequestModel.statusApproved,
      omRespondedAt: DateTime.utc(2026, 8, 9, 12),
      overallStatus: WithdrawalRequestModel.statusApproved,
      fulfilledAt: DateTime.utc(2026, 8, 9, 13),
    );
    expect(withdrawalIsActionableForRole(r, withdrawalRoleOm), isFalse);
    expect(withdrawalStatusBadgeLabel(r, withdrawalRoleSem), 'تم السحب');
  });
}
