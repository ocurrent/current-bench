ALTER TABLE benchmarks ALTER COLUMN benchmark_name DROP NOT NULL;
UPDATE benchmarks SET benchmark_name = NULL WHERE benchmark_name = 'default';