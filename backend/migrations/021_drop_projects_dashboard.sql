-- Remove Projects Dashboard completely (sheet blobs + notes + leftover rows).

DROP TABLE IF EXISTS projects_dashboard_notes CASCADE;
DROP TABLE IF EXISTS projects_dashboard_sheet CASCADE;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'notifications'
  ) THEN
    DELETE FROM notifications
     WHERE event_type ILIKE 'projects_dashboard%'
        OR attachment_source = 'projects_dashboard';
  END IF;
END $$;
