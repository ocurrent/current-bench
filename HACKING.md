# Hacking on OCaml Benchmarks

This document contains instructions for working on the OCaml Benchmarks project.

## Requirements

- Docker version 20.10.5 and docker-compose version 1.28.6 is required.


## Development environment

OCaml Benchmarks uses a dedicated docker environment for development purposes. No other dependencies apart from docker are needed to run the project locally.

The following files define the development environment:

* `./environments/development.env`
* `./environments/development.docker-compose.yaml`


### Configuring the development environment

Create a file with variables for the development environment:

```
$ cp ./environments/development.env.template ./environments/development.env
```

Edit the `./environments/development.env` file and adjust the configurations variables to your liking. The following variables are provided:

| Variable                  | Default value |
|---------------------------|---------------|
| `OCAML_BENCH_DOCKER_CPU`  | `1`           |
| `OCAML_BENCH_DB_PASSWORD` | `docker`      |
| `OCAML_BENCH_GRAPHQL_KEY` | `secret`      |
| `OCAML_BENCH_TARGET_ARCH` | `amd64`       |
| `OCAML_BENCH_HOST` | `localhost`|
| `OCAML_BENCH_GRAPHQL_PORT` | `8080` |
| `OCAML_BENCH_PIPELINE_PORT` | `8081` |
| `OCAML_BENCH_FRONTEND_PORT` | `8082` |

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
| PostgreSQL database | `postgres://docker:docker@localhost:5432/docker` |

For more details and setup instructions for the `pipeline` and the `frontend` services see the `README` files in their directories.

For more details on Hasura see: <https://hasura.io/docs/1.0/graphql/manual/deployment/docker/index.html>.


## Inspecting the benchmark results in the database

The raw benchmark results (as produced by user projects) are stored in the PostgreSQL database.

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

In the development mode the database migrations located at `./pipeline/db/migrations` are applied automatically when starting the development environment with docker-compose. If for some reason you need to run the migrations manually, for example when changing the database schema, you can `docker exec` into the `pipeline` container.

Exec into the `pipeline` container and run the migrations:

```
$ docker exec -it current-bench_pipeline_1 omigrate up --verbose --source=/app/db/migrations --database=postgresql://docker:docker@db:5432/docker
omigrate: [INFO] Version 20210013150054 has already been applied
omigrate: [INFO] Version 20210101173805 has already been applied
omigrate: [INFO] Version 20210202135643 has already been applied
...
```

## Testing benchmarks locally

Testing the OCaml Benchmarks project can be tricky because it operates as GitHub App in production. For local testing convenience the development environment includes a "shadow" git repository that can be used to trigger benchmark jobs.

The repository content is located at `./local-test-repo` and it is initialized automatically when starting the development environment. Note that for the purposes of the parent repository `./local-test-repo` is not a git repository (or git submodule) because `./local-test-repo/.git` is in the `.gitignore`. This is intentional and allows to test the pipeline with an actual git repository during development.

You can make changes to the `Makefile` in `./local-test-repo`, add new test cases, etc. When new changes are committed, the running pipeline will automatically detect this and start a new build and run jobs.

> Make sure that the development environment is running before changing the test repo.

```
$ cd `./local-test-repo`
$ $EDITOR Makefile
$ git commit -am "Modified the benchmarks"
```

The `pipeline` logs should show something like:

```
pipeline_1    |    current.git [INFO] Detected change in "master"
pipeline_1    |        current [INFO] Created new log file at
pipeline_1    |                       /app/var/job/2021-03-15/161926-docker-build-e82ec6.log
pipeline_1    |        current [INFO] Exec: "cp" "-a" "--" "/app/local-test-repo/.git" 
pipeline_1    |                             "/tmp/git-checkout3219a5b2"
pipeline_1    |        current [INFO] Exec: "git" "-C" "/tmp/git-checkout3219a5b2" "reset" 
pipeline_1    |                             "--hard" "706782c82741a89b8d9c982860787ec10b1b95f7"
pipeline_1    |        current [INFO] Exec: "git" "-C" "/tmp/git-checkout3219a5b2" "submodule" 
pipeline_1    |                             "update" "--init" "--recursive"
pipeline_1    |        current [INFO] Exec: "docker" "build" "--iidfile" "/tmp/git-checkout3219a5b2/docker-iid" 
pipeline_1    |                             "--" "/tmp/git-checkout3219a5b2"
...
```

> **WARNING**: When committing changes to the local test repo, make sure you are doing so in the main top-level git repository.


## Production environment

The production environment is very similar to the development one. The main difference in the configuration is the operational mode of the pipeline: with the development mode a local testing repository is used, while in production the pipeline starts using the `github_app` mode. This requires a few additional configuration options.

The following files define the production environment:

* `./environments/production.env`
* `./environments/production.docker-compose.yaml`


### Configuring the production environment

Create a file with variables for the production environment:

```
$ cp ./environments/production.env.template ./environments/production.env
```

Edit the `./environments/production.env` file and adjust the configurations variables to your liking.


#### Copy the production GitHub private key

The GitHub private key needs to be copied into the docker volume used by the pipeline.

Assuming that the private key is saved in `ocaml-bench-github-key` at the project's root folder:

```
$ docker run -it --rm -v $PWD/ocaml-bench-github-key:/mnt/ocaml-bench-github-key -v current-bench_pipeline_var:/mnt/pipeline_var alpine cp /mnt/ocaml-bench-github-key /mnt/pipeline_var/ocaml-bench-github-key
```

#### Adding a docker volume for data dependencies
`current-bench` supports benchmarks that have data dependency. You can add the dependencies to a
docker volume which is then mounted to the pipeline container in `docker-compose`.

To create a docker volumes you should run:
```
$ docker volume create bench-data
```
You can add the data required to your `bench-data` volume by inspecting the volume and copying the data directly to the path listed in the inspect results.
```
$ docker volume inspect
```

The underlying assumption here is that the `make bench` target would know that the dependencies live in the `bench-data` folder inside the container.

### Starting the production environment

Make sure that the `./environments/production.env` exists and has the correct configuration.

Start the docker-compose environment:

```
$ make start-production
docker-compose \
		--project-name="current-bench" \
		--file=./environments/production.docker-compose.yaml \
		--env-file=production.env \
		up \
		--detach
Starting current-bench_db_1 ... done
Starting current-bench_db-migrate_1 ... done
Recreating current-bench_pipeline_1 ... done
Attaching to current-bench_db_1, current-bench_db-migrate_1, current-bench_pipeline_1
...
```

### Some errors you might run into

1. If docker cannot find the environment file, you have to provide the full path to the env file in the Makefile for the specific make target.
2. If there's a `docker-compose` error, you need to upgrade `docker-compose` to the latest version.
3. There might be a process already listening on 5432 (port used by Postgres) when you get this error:
```
ERROR: for current-bench_db_1  Cannot start service db: driver failed programming external connectivity on endpoint current-bench_db_1 (8db805bf1bd343d8b12271c511e6c32c19be70ebed753ff4dad504e5ffdfba54): Error starting userland proxy: listen tcp4 0.0.0.0:5432: bind: address already in use
```
You have a postgres server running on your machine, kill the postgres process and run the make command again.

4. If the database isn't getting populated, it is most likely that the `make bench` command that the pipeline runs failed. You can look for the logs in`var/job/<date>/<-docker-pread-.log>` to find out why the command failed. Once you fix it, the pipeline should start populating the database. 

