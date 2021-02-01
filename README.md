
Prototype for running predictable, IO-bound benchmarks in an ocurrent pipeline. This is *work in progress*.

See general instructions in [ocaml-bench-scripts](https://github.com/ocaml-bench/ocaml_bench_scripts/) for configuring the benchmarking hardware. In particular, you need an isolated CPU to run the benchmarks on.

Use the `—docker-cpu` parameter to pin the benchmark to a single CPU. This will pass the `—cpuset-cpus` parameter to Docker behind the scenes to run the container on a single core.

The main difference from the scripts hosted in [ocaml-bench-scripts](https://github.com/ocaml-bench/ocaml_bench_scripts/) and this ocurrent pipeline is that the tasks will be executed inside docker containers. This requires a few more adjustments to how the containers are launched. Most of this is handled automatically by the pipeline by passing parameters to Docker. Some additional details are documented below.

## Running the pipeline

Before you can start the pipeline, you need to setup the Postgres instance.
The `docker-compose` file will both 
1. setup the postgres instance
2. start the graphql engine

First you will need to build the docker images, and pass the build argument to the `docker-compose build` command.

```
docker-compose build --build-arg FRONTEND_DIRECTORY="<location of frontend directory>"
```

You can clone the frontend from [here](https://github.com/ocurrent/current-bench/). You might also need to setup the
FRONTEND_DIRECTORY as an env variable before you can `docker-compose build`.

The graphql engine can be protected by setting up `GRAPHQL_KEY` as an env variable.

You can then run,
```
$ docker-compose up -d
```
to start the postgres database, grahpql engine and the frontend.

The postgres instance will be available on port `5432` and if youwant to access it locally you can run:
```
$ psql -h localhost:5432 -U docker
```

Build the pipeline:
```# install dependencies (requires postgres, libpq-dev library)
$ opam install --deps-only .
# build
$ dune build bin/main.exe
```

Build and run the pipeline:
```
# Monitor a local Git repository:
dune exec bin/main.exe -- local "/home/user/repos/mirage/index" \
    --docker-cpu 3 \
    --conn-info "host=localhost user=docker port=5432 dbname=docker password=docker" \
    --port=8081 \
    --verbose

# Monitor a GitHub repository:
dune exec bin/main.exe -- github mirage/index \
    --github-token-file <your_github_token> \
    --oauth-user <user_github_user_name> \
    --docker-cpu 3 \
    --conn-info "host=localhost user=docker port=5432 dbname=docker password=docker" \
    --port=8081 \
    --verbose
```

You can find more options for different configurations, posting message to slack, etc by running `--help` to the pipeline executable.

### Benchmarks format

If you want to enroll your repository or setup this benchmark repository for your repository,
we make the following assumptions.

1. There is a `make bench` target which can run the benchmarks.
2. The benchmarks results are json with of the following format:
```
{
  "name": <name-of-the-benchmark>
  "results" : [
    {
      "name": <name-of-the-test>,
      "metrics": {
        "<metric-1>": "",
        "<metric2>": "",
        ...
      },
     ...
    }
  ]
}
```

> Note: multiple concatenated JSON objects can be produced and will be interpreted as different benchmarks. The name of the benchmark is optional when there is only one output, but must be present if multiple result objects are produced.

[Here's](https://gist.github.com/gs0510/9ef5d47582b7fbf8dda6df0af08537e4) an example from [index](https://github.com/mirage/index) with regards to what the format looks like.

The metadata about `repo`, `branch` and `commit` is added by the pipeline. Your repo only needs to output the results as a json.

### Starting a graphql engine connected to the Postgres Database

Follow instructions from instructions here: https://hasura.io/docs/1.0/graphql/manual/deployment/docker/index.html

### Troubleshooting

You can `export FRONTEND_DIRECTORY=<location of frontend directory>` as a env variable if it is ignored by `docker-compose build`.

If you run several times `docker-compose up` and failing to load the DB for some reasons, remember to remove the `db_data` folder before trying again, as [the `init.sql` is only run once](https://stackoverflow.com/questions/53249276/docker-compose-mysql-init-sql-is-not-executed).

On some computers, the docker containers have limited memory. If you get a docker error, try using a smaller data set for benchmarking, by chaging the run arguments of `index/bench` as follows:
```ocaml
      Docker.pread ~run_args image
        ~args:
          [
            "/usr/bin/setarch";
            "x86_64";
            "--addr-no-randomize";
            "_build/default/bench/bench.exe";
            "-d";
            "/dev/shm";
            "--json";
            "--nb-entries";
            "10000";
          ]
```

## IO performance

The results of IO bound benchmarks can vary greatly between different device/storage types and how they are configured. For this prototype we’re aiming for predictable results so we are using an in-memory `tmpfs` partition in `/dev/shm` for all storage.

The `—docker-shm-size` parameter can be passed to the pipeline to adjust the size of the `tmpfs` partition. The default is 4G.

`tmpfs` partitions are similar to `ramfs` partitions in that the content will be stored entirely in internal kernel cache, but they have a size limitation and may trigger swapping. It is therefore important to make sure that the system is configured in such a way that swapping doesn’t occur while the benchmark is running. For more details about `tmpfs`/`ramfs` see https://www.kernel.org/doc/Documentation/filesystems/tmpfs.txt.

## NUMA considerations

If running on a system with NUMA enabled the `tmpfs` file system should be allocated in a memory area that is local to the core running the benchmark. Otherwise the kernel could allocate this in different areas over time and affect the IO performance results. To avoid this issue, the `tmpfs` volume can be created with a specific memory allocation policy.

The pipeline provides a `—docker-numa-node` command line parameter that forces the `tmpfs` volume in `/dev/shm` to be allocated from a specific NUMA node. `lscpu` shows which NUMA nodes are local to each core.

NOTE: Although it should be possible to get good results on a NUMA enabled system, we do not plan to use this in production and have limited experience with it. The main reason is that the system wide optimisations required would likely reduce performance for general tasks, while the benchmark itself only runs on a single core. This makes it more suitable to run on a dedicated, smaller server, which typically has less memory and doesn’t require NUMA.

## ASLR

ASLR affects performance as the memory layout is changed each time the benchmark is loaded. The ocurrent pipeline disables ASLR inside the container automatically by wrapping the benchmark command in a call to `setarch [...] --addr-no-randomize`. This is normally blocked by the default Docker seccomp profile, so we have modified the profile to allow [`personality(2)`](http://man7.org/linux/man-pages/man2/personality.2.html) to be invoked with the `ADDR_NO_RANDOMIZE` flag.


