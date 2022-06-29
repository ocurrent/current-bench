ALTER TABLE benchmarks
    ADD COLUMN target_version varchar(256) NOT NULL default '',
    ADD COLUMN target_name varchar(256) NOT NULL default '';

ALTER TABLE benchmark_metadata
    ADD COLUMN target_version varchar(256) NOT NULL default '',
    ADD COLUMN target_name varchar(256) NOT NULL default '';
