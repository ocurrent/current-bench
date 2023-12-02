# `current-bench` User Manual

Welcome to the `current-bench` User Manual. `current-bench` is a benchmarking tool provided by Tarides, specifically designed for projects using the OCaml programming language. It automates the process of monitoring, executing, and displaying benchmarks for OCaml projects directly from GitHub repositories. This tool serves benchmark results through a user-friendly web dashboard, allowing you to easily track performance changes over time.

This manual is your guide to setting up `current-bench` with your OCaml projects. It covers everything from initial setup, running benchmarks, to navigating the benchmarking dashboard. We'll also delve into advanced topics for seasoned users and provide insights into the inner workings of `current-bench`.

## Getting Started

### Preparing Your Repository

To get started, you’ll need to setup your repository to be compatible with `current-bench`.  This section walks you through the necessary steps to prepare your OCaml project for benchmarking with `current-bench`.

#### Basic Requirements

* **.opam File:** Ensure your project's root contains a .opam file. This file should list all dependencies and metadata. It's a standard file used to manage OCaml projects.
* **Makefile:** Your benchmarks should be executable with the command `make bench` from the root of your project. If you don't already have a Makefile, you'll need to create one that can run your benchmarks. Make sure that the output of `make bench` conforms to `current-bench`'s [JSON specification](./json_spec.md).
* **demo project:** You can find a sample project with this setup in [local-repos/test](../local-repos/test).

#### Advanced Setup Options

To use OCaml 5.0, no additional setup is required. If you require a specific OCaml version, you can request the `current-bench` maintainers to configure your benchmarks to be run using a specific version of OCaml.

Or, you can create a `bench.Dockerfile` at your project root and configure your specific version of OCaml or any other special dependencies your project may have. This file should include necessary system dependencies, the correct OCaml version, and a Makefile to run benchmarks.

When present, benchmarks will execute within a Docker container built from this `bench.Dockerfile`.

### Enrolling Your Repository

After setting up your repository, the next step is to enroll it with `current-bench` for continuous benchmarking.

1. **Admin Access**: Ensure you have admin access to the GitHub organization hosting your repository. For private repositories, this typically means access to your own account.

2. **Install via GitHub Marketplace**:
   - Visit the [current-bench application page](https://github.com/marketplace/ocaml-benchmarks) on GitHub Marketplace.
   - Click "Install it for free".
   - Select "only select repositories" and choose the repository you wish to benchmark.
   - For personal projects, you might need to enable Two-Factor Authentication (2FA).

3. **Approval Process**:
   - Since `current-bench` is in an experimental stage, user approvals are manual.
   - Request approval from the Tarides team. They will notify you once your repository is approved.

4. **Start Monitoring**:
   - Once approved, `current-bench` will begin benchmarking your repository.
   - Access your benchmarks at [https://bench.ci.dev/](https://bench.ci.dev/) and find your repository in the dropdown menu.

With these steps completed, you are ready to use `current-bench` for your OCaml projects.
The next sections will guide you through running benchmarks and interpreting results on the dashboard.

## Running Benchmarks

This section guides you through the process of executing benchmarks with `current-bench`, from marking pull requests (PRs) for benchmarking to monitoring benchmark progress.

### Creating a New Benchmark Test

To add and run new benchmark tests:

1. Update the benchmark executable being run by `make bench` to add a new entry in the `results` list of the JSON output.
1. Push these changes to a branch and create a PR to trigger the benchmarking, as described in the previous section.
1. You should see an entry `ocaml-benchmarks` in the list of PR checks on GitHub.

### Marking a PR for Benchmarks

By default, `current-bench` runs benchmarks on every PR for repositories enrolled in the service. However, you can configure `current-bench` to run benchmarks only on PRs tagged with a specific label.

1. **Applying Labels to PRs**:
   - When creating or updating a PR, add the designated label (as specified in your repository's `current-bench` configuration) to mark it for benchmarking.
   - Note: `current-bench` will not trigger benchmarks for PRs if the label is added after the PR creation. To include such PRs, update the PR (e.g., with a new commit) after applying the label.

2. **Triggering Benchmarks**:
   - Benchmarks will automatically start when a PR with the specified label is opened or updated.
   - For PRs already in the system without the label, adding a new commit will trigger the benchmarking process.

3. **Monitoring Progress**:
   - Once triggered, you can monitor the progress of benchmarks via the `current-bench` dashboard. This will show real-time updates and results as the benchmarks are executed.

## Configure Benchmarks

Tailoring the execution of benchmarks in `current-bench` to fit the specific needs of your project is managed through a configuration file on a per-repository basis. These configurations are centralized in the `tarides/infrastructure` repository, managed privately. To modify your benchmarking configurations, contact the Tarides maintainers with the changes you require.

1. **`worker` - Benchmark Execution Mode:** Choose between sequential only or parallel (multicore) benchmarks.
  Note: The default setup is for sequential benchmarks. Specify a `worker` for parallel benchmarks.
2. **`image` - Docker Image:** Specify a predefined Docker image for running benchmarks, ensuring a consistent and controlled benchmarking environment.
3. **`dockerfile` - Custom Dockerfile:** Opt to use a custom Dockerfile for more tailored environments, allowing for specific dependencies and settings.
4. **`bench_repo` - Separate Benchmark Repository:** If benchmarks are housed in a different repository from the main codebase, define this using `bench_repo`.
5. **`schedule` - Scheduled Benchmark Runs:** Set benchmarks to run automatically on a defined schedule, like nightly or weekly, to consistently monitor performance.
6. **`if_label` - Conditional Benchmark Runs on PRs:** Configure benchmarks to execute only for PRs marked with a specific label, focusing performance analysis on targeted changes.
7. **`build_args` - Docker Build Arguments:** Specify particular build arguments for Docker, providing additional flexibility in the Docker image build process.
8. **`branches` - Benchmarking Multiple Branches:** Set up benchmark runs on multiple long-standing branches to track performance across various development streams.
9. **`notify_github` - GitHub Integration for Benchmark Results:** Automate the posting of GitHub comments with benchmark results for significant changes. Optionally, include a label to filter which PRs receive automated benchmark result posts.
  Note: For PRs initially without the specified label, trigger a new benchmark run by force pushing to the branch.

## Using the Benchmarking Dashboard


### Accessing the Tool and CI Dashboard

Access the benchmarking dashboard for your project by visiting the URL provided by current-bench, typically in the format `https://bench.ci.dev/<your-org>/<your-repo>`.

If the benchmarks are run on multiple different environments, you can use the dropdown in the left sidebar to select the environment for which you want to view the benchmark results for.

### Interpreting Results

#### Dashboard Layout

When you access the dashboard, you'll see the results for the main branch displayed by default, which serves as a benchmark for all subsequent changes. You can select a PR from the list to view specific results associated with that change.

#### Comparing PR Branch and Main Branch Results

The UI displays the last commit hash of the PR's commit for which the comparison is being performed. It's a good idea to verify that this is the commit you want to compare.

A table of comparison is displayed on the PR branch dashboard, which gives a comparison of the value of each metric on the last commit of the PR, vs the main branch value. There's also a %age delta of the values that would help you notice any significant changes to drill further into.

There's also a graph comparing the value of the metrics that could make it easier to notice sharp changes in the metrics to further investigate and understand what causes them.

## Advanced Use Cases

### Submitting Benchmark Data via API

For users looking to submit benchmark data programmatically, the API offers a flexible way to integrate with the benchmarking system. This feature allows for flexibility when a project wishes to run their benchmarks on their own benchmarking systems, but wish to use the `current-bench` infrastructure for visualisation.

1. **Obtain an API Token**: Contact the benchmarking team to receive a valid HTTP `Bearer` token for authorization.
2. **Prepare Your Data**: Format your benchmark results in JSON, including essential details like `repo_owner`, `repo_name`, `commit`, and the benchmarks' `results`. The format is similar to the results outlined in the JSON Format for Results section.
3. **Submit a POST**: POST your data to the API endpoint. Here's a template:

```sh
curl -X POST -H 'Authorization: Bearer <Your-Token>' \
https://bench.ci.dev/benchmarks/metrics --data-raw '<Your-Benchmark-JSON>'
```

Replace `<Your-Token>` with your provided token and `<Your-Benchmark-JSON>` with the JSON string of your results.

An example payload might look like this:
```json
{
  "repo_owner": "ocurrent",
  "repo_name": "current-bench",
  "commit": "c66a02ea...",
  "pull_number": 286,
  "run_at": "2022-01-28T12:42:02+05:30",
  "duration": "12.45",
  "benchmarks": [...]
}
```

Ensure the `run_at` field is in the RFC3339 format and the `duration` is expressed in seconds.

### Managing Data Dependencies

For projects with data dependencies, `current-bench` ensures that your datasets are readily available to your benchmarks during runtime.

* Your data is stored within a Docker volume named `current-bench-data`.
* This volume is mounted to the benchmark running environment at the path `/home/opam/bench-dir/current-bench-data`.

When writing your benchmarks, reference the data using the mounted volume path:

```
/home/opam/bench-dir/current-bench-data/<org_name>/<repo_name>/<data_file>
```

Replace `<org_name>`, `<repo_name>`, and `<data_file>` with your GitHub organization's name, the repository's name, and the specific data file you need, respectively.

## Troubleshooting

Here are common problems you may encounter and how you can address them:
1. **Graphs Not Displaying in Dashboard**
    * **Nested Benchmarks**: If your JSON has a `name` field at the top level, benchmarks are nested. Click on the `name` value in the left sidebar to view graphs. Reference:[issue #423](https://github.com/ocurrent/current-bench/issues/423).
    * **JSON Generation**: Ensure that the JSON data is generated by `make bench`.
    * **Validation**: Use `cb-check` to validate the JSON output for format compatibility.
2. **Benchmark Run Hangs and Times Out**
    * **Multicore Benchmarks**: For multicore benchmarks, ensure they are run on a multicore worker. Contact the Infrastructure team for configuration adjustments.
3. **Job Cancelled with Message ‘Auto-cancelling job because it is no longer needed’**
    * **Branch Deletion**: If a branch is deleted while a benchmark is running, `current-bench` will automatically cancel the job. This behaviour is documented in [issue #458](https://github.com/ocurrent/current-bench/issues/458).

### Additional Troubleshooting Tips

- **Check Recent Changes**: If issues arise after changes to your repository or benchmark configuration, review these changes as they may be the cause.
- **Monitor System Resources**: For local setups, monitor system resources during benchmark runs. Insufficient resources can lead to timeouts or failures.
- **Consult Logs**: Check `current-bench` logs for any error messages or clues that can help diagnose the problem.

### Reporting Issues

If after following the above troubleshooting section you're still encountering issues, open an issue on `current-bench`'s [issue tracker](https://github.com/ocurrent/current-bench/issues).
