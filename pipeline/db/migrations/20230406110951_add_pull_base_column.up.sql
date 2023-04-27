ALTER TABLE benchmark_metadata ADD pull_base varchar(100);
ALTER TABLE benchmarks ADD pull_base varchar(100);

WITH default_branches (repo_id, pull_base) AS (VALUES
('odis-labs/streaming', 'master'),
('art-w/ocaml-benching', 'master'),
('gridbugs/dune-monorepo-bench', 'main'),
('Zineb-Ada/merlin', 'master'),
('ocaml-multicore/kcas', 'main'),
('mirage/irmin', 'main'),
('ocaml-community/yojson', 'master'),
('art-w/cb-dev-test', 'master'),
('punchagan/current-bench', 'main'),
('mirage/repr', 'main'),
('mirage/index', 'main'),
('ocaml-ppx/ppxlib', 'main'),
('Zineb-Ada/bechamel-fact', 'master'),
('ocaml-bench/sandmark', 'main'),
('ocaml/dune', 'main'),
('ElectreAAS/sandmark', 'main'),
('ocaml-multicore/lockfree', 'main'),
('Lucccyo/cachecache', 'main'),
('ocaml-ppx/ocamlformat', 'main'),
('art-w/ocaml', 'cb-comanche'),
('Zineb-Ada/eqaf', 'master'),
('ocaml/merlin', 'master'),
('ElectreAAS/Paradict', 'master')
),
update_metadata AS (
  UPDATE benchmark_metadata
  SET pull_base = default_branches.pull_base
  FROM default_branches
  WHERE benchmark_metadata.repo_id = default_branches.repo_id
  RETURNING benchmark_metadata.repo_id
)
UPDATE benchmarks
SET pull_base = default_branches.pull_base
FROM default_branches
WHERE benchmarks.repo_id = default_branches.repo_id;
