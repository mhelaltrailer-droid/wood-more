-- حذف بيانات تشغيلية: خطط العمل، المقاولين، هيكلة المشاريع/المخازن،
-- أرصدة المخازن، سحوبات الخامات، والحضور/الانصراف.
-- لا يحذف المستخدمين ولا العهدة/الماليات ولا التقارير اليومية (daily_reports).

BEGIN;

DELETE FROM withdrawal_requests;
DELETE FROM executed_plans;
DELETE FROM detailed_reports;
DELETE FROM location_withdrawal;
DELETE FROM location_materials;
DELETE FROM ir_mir_uploads;
DELETE FROM project_stock_ledger;
DELETE FROM project_stock;
DELETE FROM building_cutlist_images;
DELETE FROM building_materials;
DELETE FROM units;
DELETE FROM buildings;
DELETE FROM zones;
DELETE FROM project_locations;
DELETE FROM projects;
DELETE FROM contractors;
DELETE FROM attendance_records;

COMMIT;
