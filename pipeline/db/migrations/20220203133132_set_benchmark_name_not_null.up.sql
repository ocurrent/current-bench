UPDATE benchmarks SET benchmark_name = 'default' WHERE benchmark_name IS NULL;
ALTER TABLE benchmarks ALTER COLUMN benchmark_name SET NOT NULL;