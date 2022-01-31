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

Before you start your docker containers for the first time, you'll
need to create an external docker volume, like this:

```
docker volume create --name=current-bench-data
```

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

### Running commands in the docker containers

The `scripts/` directory has a helper script `dc.sh` that makes it easy to run
`docker-compose` commands without having to manually provide the `--file`,
`--env` and `--project-name` arguments.

```sh
./scripts/dc.sh exec db psql -U docker
```

### Restarting services upon source code changes

The frontend has hot-reloading configured and any changes made to the frontend
files are automatically detected and reflected in the browser.

Changes made to the pipeline source will need a rebuild and restart of the
pipeline container. This can be achieved by running the following command:

```sh
make rebuild-pipeline
```

### Starting only the database and the frontend

It is possible to start just the database and the front-end without starting the `pipeline` that watches repositories and runs benchmarks. This is useful to visualize benchmarks run elsewhere using current-bench's frontend. To run only the db, frontend and graphq-engine containers, run the following command:

```sh
./scripts/dc.sh up --build frontend db graphql-engine db-migrate
```

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

### Creating new migrations

New migrations can be created using the `omigrate create` command, when the
pipeline container is running.


```
$ docker exec -it current-bench_pipeline_1 omigrate create --verbose --dir=/app/db/migrations add_version_column_to_benchmarks
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

## Testing benchmarks with the GitHub app

In order to test locally the behaviour of the GitHub App, you will need to create your own private application on GitHub. It will behave just like production, with webhooks, graphql and PR status updates:

1. [**Create a private Current-Bench GitHub App**](https://github.com/settings/apps/new?name=CB%20dev%20test&url=https:%2F%2Fidonothaveaurl.com&public=false&webhook_active=true&webhook_url=https:%2F%2Fwillbesetuplater.com&pull_requests=write&statuses=write&repository_hooks=write&events=pull_request) (<- this link will pre-configure the required settings)
2. After creation, note the **App ID: 1562..** number on the top of the page
3. Then scroll to the bottom and ask github to **generate a private key**: save the file in `environments/cb-dev-test.pem`
4. Create a **webhook secret** on your computer : `echo -n mysecret > environments/github.secret` (it should not contain a carriage return `\n` hence the `echo -n`)
5. Install your private GitHub application on a repository of your choice!

In order for github to send webhooks to your local current-bench, you need a public URL. Create a free account on [**ngrok.com**](https://ngrok.com) and note the **auth token 12m4gI45Vzhblablabla...**

Finally edit your `environments/development.env` to add all the variables:

```
OCAML_BENCH_NGROK_AUTH=12m4gI45Vzhblablabla...
OCAML_BENCH_GITHUB_APP_ID=156213...
OCAML_BENCH_GITHUB_ACCOUNT_ALLOW_LIST=your-github-username...
OCAML_BENCH_GITHUB_PRIVATE_KEY_FILE=cb-dev-test.pem
OCAML_BENCH_GITHUB_WEBHOOK_SECRET_FILE=github.secret
```

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
$ docker volume create current-bench-data
```
You can add the data required to your `current-bench-data` volume by inspecting the volume and copying the data directly to the path listed in the inspect results.
```
$ docker volume inspect
```

The underlying assumption here is that the `make bench` target would know that the dependencies live in the `current-bench-data` folder inside the container.

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

### Configuring where to run benchmarks

The `environments/production.conf` lists the repositories that can be run on remote workers:

```json
[
  { "name": "gs0510/decompress", "worker": "grumpy", "image": "ocaml/opam:debian-11-ocaml-4.14" }
]
```

You can repeat the same "author/repo" multiple times with different configurations. By default, unlisted repositories will run on the default local worker.

### Adding new workers to the cluster

The `environments/production.env` should list the known workers with a comma separated list:

```
OCAML_BENCH_CLUSTER_POOLS=autumn,grumpy,comanche
```

If you change this list, you should probably update the `environments/production.conf`: New workers will not be used otherwise! And removed workers will be unavailable for the repositories that requested them.

In general, each worker will have a unique pool name -- unless you are absolutely sure that their hardware and configuration are identical. After updating the list of workers and restarting the cluster, the `capnp-secrets/` directory will be updated with the new workers:

```sh
$ ls capnp-secrets/pool-*
capnp-secrets/pool-autumn.cap  capnp-secrets/pool-grumpy.cap  ...

$ cat capnp-secrets/pool-autumn.cap
capnp://sha-256:Zs31_Pk9LvBWw03hIW1QvNZUopTOipwqYAmJW3sKD0Y@cluster:9000/1CJdWsiXEtdvzOnupvfOdLO_nz3MOxGz8wcDHj18mRE
```

The worker will need access to its `pool-name.cap` file to connect to the cluster.
To deploy a new worker to a new machine, you can clone the current-bench repository and setup the worker dependencies:

```sh
$ ssh mymachine

$ git clone 'https://github.com/ocurrent/current-bench'
$ cd current-bench/worker
$ opam install --deps-only ./cb-worker.opam

$ mkdir /path/to/internal/state  # worker needs a place of storage
```

Docker should be installed and accessible to the user that will be running the worker (you can check by running `docker ps`). To keep the worker alive, it is recommended to start it with `nohup`, `screen` or `tmux`.

```sh
$ screen -ls # to list the existing sessions
$ screen -R current-bench-worker # to recover or create the worker session
... run the worker ...
CTRL-A CTRL-D # to exit and keep the worker alive in the background
```

Now, from the `current-bench/worker` directory:

- scp the `capnp-secrets/pool-myworker.cap` that the cluster generated
- edit the `pool-myworker.cap` to make sure the worker has access to the cluster IP address: By default, the file reads `capnp://...@cluster:9000/...` but it should contain an accessible domain rather than "cluster": `capnp://...@123.0.1.2:9000/...` or `capnp://...@mycluster.com:9000/...`

You can now run the worker with a small script:

```
#!/bin/bash

dune exec --root=. ./cb_worker.exe -- \
    --name=my-worker \
    --state-dir=/path/to/internal/state \
    --ocluster-pool=./pool-myworker.cap \
    --docker-cpu=0-1,2-3
```

- The worker `--name` will show up in the build logs as `Building on <my-worker>` (for debugging)
- The `--state-dir` should point to a directory where the worker will be able to store its data
- The `--ocluster-pool` should be the filename created by the cluster.
- Finally, the `--docker-cpu` is a comma separated list of CPUs available to the worker. If there are multiple choices `A,B,C` then the worker will be able to run as many benchmarks at the same time. If there are no comma, then only one benchmark will be run at a time. A range `A-B` allow for multicore benchmarks on the cpus A to B, while a single `X` cpu number is for a single core. If ranges are used, they should have the same number of CPUs and not overlap!
