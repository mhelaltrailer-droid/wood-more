-- حذف خطط العمل (detailed_reports) ليوم 27 أبريل 2026 + سجلات التنفيذ لنفس اليوم.
-- report_datetime و plan_date مخزّنة كنص ISO في الخادم الحالي.

BEGIN;

DELETE FROM executed_plans
WHERE plan_date LIKE '2026-04-27%'
   OR left(plan_date, 10) = '2026-04-27';

DELETE FROM detailed_reports
WHERE left(report_datetime, 10) = '2026-04-27';

COMMIT;
