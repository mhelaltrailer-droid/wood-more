BEGIN;

ALTER TABLE detailed_report_lines
  DROP CONSTRAINT IF EXISTS detailed_report_lines_workers_count_check;

ALTER TABLE detailed_report_lines
  ADD CONSTRAINT detailed_report_lines_workers_count_check
  CHECK (workers_count >= 0);

COMMIT;
