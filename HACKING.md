# Hacking on OCaml Benchmarks

This document contains instructions for working on the OCaml Benchmarks project.

## Development environment

OCaml Benchmarks uses a dedicated docker environment for deveploment purposes. No other dependencies apart from docker are needed to run the project locally.

The following files are needed to start the development environment:

* `./Makefile`
* `./environments/development.env`
* `./environments/development.docker-compose.yaml`


### Configuring the environment

Create a file with variables for the development environment:

```
$ cp ./environments/development.env.template ./environments/development.env
```

Edit the `./environments/development.env` file and adjust the configurations variables to your liking. The fowlloing variables are provided:

| Variable                  | Default value |
|---------------------------|---------------|
| `OCAML_BENCH_DOCKER_CPU`  | `1`           |
| `OCAML_BENCH_DB_PASSWORD` | `docker`      |
| `OCAML_BENCH_GRAPHQL_KEY` | `secret`      |
| `OCAML_BENCH_TARGET_ARCH` | `amd64`       |

> To run the project on the Apple MacBookPro with an M1 CPU, set the `OCAML_BENCH_TARGET_ARCH` variable to `arm64`.


### Starting the development environment

Make sure that the `./environments/development.env` exists and has the correct configuration.

Start the docker-compose environment:

```
$ make start-development
docker-compose \
		--project-name="current-bench" \
		--file=./environments/development.docker-compose.yaml \
		--env-file=development.env \
		up \
		--remove-orphans
Starting current-bench_db_1 ... done
Starting current-bench_db-migrate_1 ... done
Recreating current-bench_pipeline_1 ... done
Attaching to current-bench_db_1, current-bench_db-migrate_1, current-bench_pipeline_1
...
```

This will start multiple services:

* `pipeline` - the backend service responsible for monitoring repositories and scheduling benchmark jobs.
* `db` - a PostgreSQL database for storing benchmark results.
* `db-migrate` - sets up the database and runs all schema migrations.
* `graphql-engine` - the GraphQL engine powered by [Hasura](https://hasura.io/docs/latest/graphql/core/index.html) that serves the benchmark results from the `db`.
* `frontend` - the frontend application for showing the benchmark results. Currently deployed at: <http://autumn.ocamllabs.io>.

> The `db-migrate` service is unique to the development environment. In production the database migrations MUST be applied manually.

| Service | URL |
|---|---|
| Application UI | <http://localhost:8082> |
| Pipeline UI | <http://localhost:8081> |
| Hasura GraphQL engine | <http://localhost:8080> |
| PostgreSQL database | `postgres://docker:docker@db:5432/docker` |

For mode details and setup instructions for the `pipeline` and the `frontend` services see the `README` files in their directories.


## Inspecting the benchmark results in the database

The raw benchmark results (as produced by user projects) are stored in the PostgreSQL database.

The schema for the 

Make sure that your development environment is running (see the previous section) and connect to the database and select the data:

```
$ docker exec -it current-bench_pipeline_1 psql postgres://docker:docker@db:5432/docker
psql (11.10 (Debian 11.10-0+deb10u1), server 12.6 (Debian 12.6-1.pgdg100+1))
Type "help" for help.

docker=# \dt
              List of relations
 Schema |       Name        | Type  | Owner  
--------+-------------------+-------+--------
 public | benchmarks        | table | docker
 public | schema_migrations | table | docker
(2 rows)

docker=# select count(*) from benchmarks;
```

## Working with database migrations

In the development mode the database migrations located at `./pipeline/db/migrations` are applied automatically when starting the deveploment environment with docker-compose. If for some reason you need to run the migrations manually, for example when changing the database schema, you can `docker exec` into the `pipeline` container.

Exec into the `pipeline` container and run the migrations:

```
$ docker exec -it current-bench_pipeline_1 omigrate up --verbose --source=/app/db/migrations --database=postgresql://docker:docker@db:5432/docker
omigrate: [INFO] Version 20210013150054 has already been applied
omigrate: [INFO] Version 20210101173805 has already been applied
omigrate: [INFO] Version 20210202135643 has already been applied
...
```

