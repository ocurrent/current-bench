[![OCaml-CI Build Status](https://img.shields.io/endpoint?url=https%3A%2F%2Fci.ocamllabs.io%2Fbadge%2Focurrent%2Focaml-ci%2Fmaster&logo=ocaml)](https://ci.ocamllabs.io/github/ocurrent/current-bench)

# OCaml - Continuous benchmarks

Prototype for running predictable, IO-bound benchmarks in an ocurrent pipeline. This is *work in progress*. If you want to be on the allowlist for running benchmarks for your repository, please contact @ElectreAAS, @shakthimaan, or @punchagan, or [open an issue](https://github.com/ocurrent/current-bench/issues/new).

If you're here just to enroll your repo to see nice graphs, you're in the right
place, you can jump to the [Enroll your Repository](#enroll-your-repository)
section.

If you want to run this project locally or want to contribute to improving
current-bench, see [HACKING.md](HACKING.md)

## Enroll your repository

`current-bench` uses a [GitHub
Application](https://github.com/marketplace/ocaml-benchmarks) to track all the
repositories enrolled for running benchmarks. To enroll your repository, you'll
need to:

- First, you'll need to make sure you have admin access to the organization
  that hosts your repo. If it's a private repo that just means your own
  account.

- Then, go to the app's page on the [Github
  Marketplace](https://github.com/marketplace/ocaml-benchmarks), scroll down
  and click on "Install it for free".

- Choose "only select repositories" and select the repo you want
  benchmarked. If this is a personal project, you might have to enable 2FA.

- Finally, since `current-bench` is still in an experimental stage, users have
  to be approved manually. Ask us to approve you or your org. Someone on our
  team will notify you when it's been taken care of.

Now, `current-bench` should start running benchmarks for your repository, and
you should be able to see your repo in the dropdown menu at
https://autumn.ocamllabs.io

### Configuring when and how to run the benchmarks

`current-bench` allows for some customization (per repository) for specifying
when and how to run the customization. If you need any of the customizations
listed below, or other customization, please reach out to the maintainers.

- Run sequential benchmarks only or parallel benchmarks too. ⚠️ Our default worker can only run sequential benchmarks. If you have parallel (multicore) benchmarks, do let us know! We can configure to run them on a specific worker (`worker`).
- Use a specific Docker image (`image`) or a custom Dockerfile (`dockerfile`) to run the benchmarks.
- Run benchmarks from a repository different from the code repository  (`bench_repo`)
- Run the benchmarks on a schedule - nightly, weekly, etc. (`schedule`)
- Run the benchmarks only on PRs with a specific label (`if_label`)
- Specify build-args when building the docker image (`build_args`)
- Run benchmarks on more than one long-running branches (`branches`)
- Post GitHub comments with the build results when there's a significant change
  in the results (`notify_github`).  The config value can also specify a label,
  which ensures that only those PRs with this label get notified with the
  benchmark results.  NOTE: The PR label cannot be added while the benchmark
  run has started.  To trigger a run, where the results are posted to the PR,
  you'll have to trigger a new run by (force) pushing to the branch.

## Ensuring we can run your benchmarks
To be able to run your benchmarks, current-bench assumes certain things about your repo:
- You have a `.opam` file at the root of your project specifying your dependencies and all the usual metadata.
- Your benchmarks can be run by using `make bench` at the root of your project. If you don't have one, you'll need a `Makefile`. (For example, see [this simple Makefile](https://github.com/example-ocaml-org/my-ocaml-project/blob/main/Makefile))
- Either you want OCaml 5.0.0, or you have a custom `bench.Dockerfile` at the root of your project that installs the necessary system dependencies (including opam) and the correct OCaml version.
- The results of the benchmarks are in json, with a few specific fields, see below for the exact format. The standard output of `make bench` will be searched for json matching this format.
- If a `bench.Dockerfile` is present then benchmarks will be run from within a docker container built from this file. This means `bench.Dockerfile` must set up an image containing a `Makefile` which runs benchmarks by running `make bench`.
- Benchmarks only run when:
  - opening a pull request
  - updating a remote branch which is the source of a pull request
  - merging a pull request
- ⚠️ The benchmarks are run on a single core, by default. If your benchmarks include parallel benchmarks, the repository needs to be explicitly configured to use a multicore worker. Please let the benchmarking team know about this.

### JSON format
To be able to draw graphs from your results, they need to follow a specific format.
You can automatically check that your output conforms to that format by calling `cb-check`:

<!-- remove the pin when cb-check hits opam -->
```bash
opam pin -n cb-check git+https://github.com/ocurrent/current-bench.git
opam install cb-check
your_executable | cb-check
# OR, if your_executable writes in some_file.json
cb-check some_file.json
```

A description of that format is also specified below for convenience:

```json
{
  "name": "optional-name-of-the-benchmark",
  "config": "optional-config-object",
  "results": [
    {
      "name": "name-of-the-test",
      "metrics": [
        {"name": "benchmark-name", "value": 42, "units": "benchmark-unit", "description": "benchmark-description"},
        {"name": "num_ops", "value": [0.5, 1.5, ...], "units": "ops/sec", "description": "total number of ops", "trend": "lower-is-better"},
        {"name": "time", "value": 20, "units": "sec", "description": "time for action"},
        {"name": "data-transfer", "value": {"min": 1, "max": 25.2, "avg": 19.8}, "units": "mbps", "description": "data transfer per second", "trend": "higher-is-better"},
        ...
      ],
      ...
    }
  ]
}
```
Note that the only valid `"trend"`s are `"higher-is-better"` and `"lower-is-better"`.

[Here's](https://gist.github.com/gs0510/9ef5d47582b7fbf8dda6df0af08537e4) an example from [index](https://github.com/mirage/index) with regards to what the format looks like.

The metadata about `repo`, `branch` and `commit` is added by current-bench.


### Multiple benchmarks per project

Multiple concatenated JSON objects can be produced and will be interpreted as different benchmarks. The name of the benchmark is optional when there is only one output, but must be present if multiple result objects are produced.


### Using API to submit benchmark data

Benchmarks data could also be added directly to the DB without having
`current-bench` running the benchmarks using a HTTP end-point.

For that you'll need a valid HTTP `token`, ask us and we'll provide one for you.

```sh
curl -X POST -H 'Authorization: Bearer <token>' https://autumn.ocamllabs.io/benchmarks/metrics --data-raw '
{
  "repo_owner": "ocurrent",
  "repo_name": "current-bench",
  "commit": "c66a02ea54430d99b3fefbeba4941921501796ef",
  "pull_number": 286,
  "run_at": "2022-01-28 12:42:02+05:30",
  "duration": "12.45",
  "benchmarks": [
    {
      "name": "benchmark-1",
      "results": [
        {
          "name": "test-1",
          "metrics": [
            {
              "name": "time", "value": 18, "units": "sec"
            }
          ]
        }
      ]
    },
    {
      "name": "benchmark-2",
      "results": [
        {
          "name": "test-1",
          "metrics": [
            {
              "name": "space", "value": 18, "units": "mb"
            }
          ]
        }
      ]
    }
  ]
}
'
```


## Data dependencies in your project

If you have a data dependency, then currently we add the dependency to the docker volume called `current-bench-data`.
The dependency lives in `<org_name>/<repo_name>` folder so you can assume the dependency to live in `current-bench-data/<org_name>/<repo_name>` folder.
