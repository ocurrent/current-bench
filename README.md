[![OCaml-CI Build Status](https://img.shields.io/endpoint?url=https%3A%2F%2Fci.ocamllabs.io%2Fbadge%2Focurrent%2Focaml-ci%2Fmaster&logo=ocaml)](https://ci.ocamllabs.io/github/ocurrent/current-bench)

# OCaml - Continuous benchmarks

Prototype for running predictable, IO-bound benchmarks in an ocurrent pipeline. This is *work in progress*. If you want to be on the allowlist for running benchmarks for your repository, please contact @ElectreAAS, @shakthimaan, or @punchagan, or [open an issue](https://github.com/ocurrent/current-bench/issues/new).

If you're here just to enroll your repo to see nice graphs, you're in the right place, you can jump to the next section.
If you want to run this project locally on a tuned machine, see [TUNING.md](TUNING.md).
If you're here to contribute to improving current-bench, see [HACKING.md](HACKING.md)

## The github application
- First, you'll need to make sure you have admin access to the organization that hosts your repo. If it's a private repo that just means your own account.
- Then go to the app's page on the [Github Marketplace](https://github.com/marketplace/ocaml-benchmarks), scroll down and click on "Install it for free". 
- Choose "only select repositories" and select the repo you want benchmarked. If this is a personal project, you might have to deal with 2FA there.

Done!

## Tell us about it
Since current-bench is in an experimental stage, users have to be approved manually. Ask us to approve you or your org. Someone on our team will notify you when it's been taken care of.

Now, you should be able to see your repo in the dropdown menu at https://autumn.ocamllabs.io

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

⚠️ The benchmarks are run on a single core (for now), so either don't include parallel benchmarks, or don't take the results at face value.

### JSon format
To be able to draw graphs from your results, they need to follow a specific format.
You can automatically check that your output conforms to that format by calling `cb-check`:

<!-- remove the pin when cb-check hits opam -->
```bash
opam pin -n cb-check git@github.com:ocurrent/current-bench.git
opam install cb-check
your_executable | cb-check
# OR, if your_executable writes in some_file.txt
cb-check some_file.txt
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
