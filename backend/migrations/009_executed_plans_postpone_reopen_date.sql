-- Add postponed reopen date for executed plans.
-- Safe to run multiple times.

ALTER TABLE executed_plans
  ADD COLUMN IF NOT EXISTS postpone_reopen_date TEXT;

CREATE INDEX IF NOT EXISTS idx_executed_plans_postpone_reopen_date
  ON executed_plans (postpone_reopen_date);
