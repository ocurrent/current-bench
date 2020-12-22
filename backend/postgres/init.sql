GRANT ALL PRIVILEGES ON DATABASE docker TO docker;

CREATE TABLE benchmarks(
	repositories varchar(256),
	commits varchar(50) NOT NULL,
	json_data jsonb,
	timestamp float8,
	branch varchar(256)
);

CREATE TABLE benchmarksrun (
    commits varchar(50),
    name varchar(100),
    time float8,
    ops_per_sec float8,
    mbs_per_sec float8, 
    timestamp float8,
    branch varchar(256)
);


