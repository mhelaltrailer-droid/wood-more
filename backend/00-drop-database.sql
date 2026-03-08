-- =============================================================================
-- Run this ONLY when you want to remove the app database and user and start over.
-- Connect as superuser (e.g. "postgres") to the default database ("postgres").
-- Then run 01-create-database.sql, then connect to wood_more and run init-db.sql.
-- =============================================================================

DROP DATABASE IF EXISTS wood_more;
DROP USER IF EXISTS wood_more;
