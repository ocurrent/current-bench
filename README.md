# OCaml - Continuous benchmarks

Prototype for running predictable, IO-bound benchmarks in an ocurrent pipeline. This is *work in progress*.

## Enroll your project

If you want to enroll your repository or setup this benchmark repository for your repository, we make the following assumptions.

1. There is a `make bench` target which can run the benchmarks.
2. The benchmarks result is a JSON object of the following format:

```bash
{
  "name": <optional-name-of-the-benchmark>,
  "config": <optional-config-object>,
  "results": [
    {
      "name": <name-of-the-test>,
      "metrics": {
        "<metric-1>": <numeric-value>,
        "<metric-2>": [<numeric-value>, ...],
        ...
      },
     ...
    }
  ]
}
```

[Here's](https://gist.github.com/gs0510/9ef5d47582b7fbf8dda6df0af08537e4) an example from [index](https://github.com/mirage/index) with regards to what the format looks like.

The metadata about `repo`, `branch` and `commit` is added by the pipeline.


### Multiple benchmarks per project

Multiple concatenated JSON objects can be produced and will be interpreted as different benchmarks. The name of the benchmark is optional when there is only one output, but must be present if multiple result objects are produced.


## Tuning the environment

See general instructions in [ocaml-bench-scripts](https://github.com/ocaml-bench/ocaml_bench_scripts/) for configuring the benchmarking hardware. In particular, you need an isolated CPU to run the benchmarks on.

Use the `—docker-cpu` parameter to pin the benchmark to a single CPU. This will pass the `—cpuset-cpus` parameter to Docker behind the scenes to run the container on a single core.

The main difference from the scripts hosted in [ocaml-bench-scripts](https://github.com/ocaml-bench/ocaml_bench_scripts/) and this ocurrent pipeline is that the tasks will be executed inside docker containers. This requires a few more adjustments to how the containers are launched. Most of this is handled automatically by the pipeline by passing parameters to Docker. Some additional details are documented below.


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

