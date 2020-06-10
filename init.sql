GRANT ALL PRIVILEGES ON DATABASE docker TO docker;

CREATE TABLE benchmarks(
	repositories varchar(256),
	commits varchar(50),
	json_data jsonb
);

CREATE TABLE benchmarksrun (
    commits varchar(50),
    name varchar(100),
    time float8,
	ops_per_sec float8,
	mbs_per_sec float8 
);


