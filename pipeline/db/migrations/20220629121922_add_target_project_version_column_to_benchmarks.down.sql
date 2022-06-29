ALTER TABLE benchmarks
    DROP COLUMN target_version,
    DROP COLUMN target_name;

ALTER TABLE benchmark_metadata
    DROP COLUMN target_version,
    DROP COLUMN target_name;
