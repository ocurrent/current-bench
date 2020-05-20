CREATE USER docker;
CREATE DATABASE docker;
GRANT ALL PRIVILEGES ON DATABASE docker TO docker;

CREATE TABLE benchmarks(
	repositories varchar(256),
	commits varchar(50)
);

CREATE TABLE benchmarksrun (
    commits varchar(50),
    name varchar(100),
    time float8,
	ops_per_sec float8,
	mbs_per_sec float8 
);


