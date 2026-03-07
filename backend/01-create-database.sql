-- =============================================================================
-- Step 1: Create a dedicated database for Wood & More (run this FIRST)
-- =============================================================================
-- In Beekeeper: connect to the default database (e.g. "postgres"), then run
-- this script. After that, create a NEW connection to database "wood_and_more"
-- and run init-db.sql (tables and seed data).
-- =============================================================================

CREATE DATABASE wood_and_more
  WITH
  ENCODING = 'UTF8';

-- Optional: if your server has a specific owner or locale, you can use:
-- CREATE DATABASE wood_and_more WITH ENCODING = 'UTF8' OWNER = postgres;
