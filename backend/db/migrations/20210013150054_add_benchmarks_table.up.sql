	CREATE TABLE benchmarks(
		run_at timestamp without time zone not null,
		repo_id varchar(256) NOT NULL,
		commit varchar(50) NOT NULL,
		branch varchar(256),
		pull_number integer,
		name varchar(256),
		metrics jsonb
	);