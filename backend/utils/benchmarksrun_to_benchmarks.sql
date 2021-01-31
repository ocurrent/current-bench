
-- Populates the benchmarks table with all the records from benchmarksrun.
BEGIN;
INSERT INTO
    benchmarks(run_at, repo_id, commit, branch, pull_number, test_name, metrics)
SELECT
    to_timestamp(timestamp) AS run_at,
    split_part(branch, '/', 1) || '/' || split_part(branch, '/', 2)  AS repo_id,
    commits AS commit,
    CASE
    WHEN not (split_part(branch, '/', 3) ~ '^[0-9]+$') THEN
        split_part(branch, '/', 3)
    ELSE
        NULL
    END AS branch,
    CASE
    WHEN split_part(branch, '/', 3) ~ '^[0-9]+$' THEN
        split_part(branch, '/', 3)::integer
    ELSE
        NULL
    END AS pull_number,
    name AS test_name,
    ('{"time":' || time ||
    ', "ops_per_sec":' || ops_per_sec || 
    ', "mbs_per_sec":' || mbs_per_sec || '}')::jsonb AS metrics
FROM
    benchmarksrun;
COMMIT;