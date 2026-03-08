-- =============================================================================
-- Step 1: Create user and database for Wood & More (run this FIRST)
-- =============================================================================
-- Connect as superuser (e.g. "postgres") to the default database ("postgres"),
-- then run this script. The API connects as user wood_more with password "password".
-- After this, connect to database "wood_more" (user wood_more, password "password")
-- and run init-db.sql.
-- =============================================================================

CREATE USER wood_more WITH PASSWORD 'password';

CREATE DATABASE wood_more
  WITH
  ENCODING = 'UTF8'
  OWNER = wood_more;
