CREATE TYPE benchmarks_status AS ENUM (
  'build_started',
  'build_failed',
  'run_started',
  'run_failed',
  'run_succeeded'
);


CREATE TABLE benchmarks_new (
  started_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  repo_id CHARACTER VARYING(256) NOT NULL,
  commit CHARACTER VARYING(50) NOT NULL,
  branch CHARACTER VARYING(256) DEFAULT NULL,
  pull_number INTEGER DEFAULT NULL,
  build_job_id CHARACTER VARYING(256) NOT NULL,
  run_job_id CHARACTER VARYING(256) DEFAULT NULL,
  status benchmarks_status DEFAULT NULL,

  output json,

  PRIMARY KEY (started_at, repo_id)
);