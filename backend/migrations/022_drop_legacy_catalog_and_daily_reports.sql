-- Remove unused catalog (zones/buildings/units/stockpiles/cutlists) and daily reports.

ALTER TABLE IF EXISTS detailed_report_lines
  DROP CONSTRAINT IF EXISTS detailed_report_lines_zone_id_fkey;
ALTER TABLE IF EXISTS detailed_report_lines
  DROP CONSTRAINT IF EXISTS detailed_report_lines_building_id_fkey;

DROP TABLE IF EXISTS public.units CASCADE;
DROP TABLE IF EXISTS public.building_materials CASCADE;
DROP TABLE IF EXISTS public.building_cutlist_images CASCADE;
DROP TABLE IF EXISTS public.daily_reports CASCADE;
DROP TABLE IF EXISTS public.buildings CASCADE;
DROP TABLE IF EXISTS public.zones CASCADE;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'notifications'
  ) THEN
    DELETE FROM notifications
     WHERE attachment_source IN ('unit', 'building_material', 'building_cutlist', 'daily_report')
        OR event_type ILIKE 'daily_report%';
  END IF;
END $$;
