# JSON Format for Benchmark Results

For `current-bench` to interpret and visualise your benchmark results, the output of the benchmark must conform to `current-bench`'s JSON specification.

This section details the structure and contents of the JSON output required by `current-bench`.

## Key Components of the JSON Format

Your benchmark results should be formatted as a JSON object with the following key components:

1. **Benchmark Name** (optional): A name identifier for the entire benchmark suite.
   
   ```json
   "name": "optional-name-of-the-benchmark",
   ```

2. **Configuration Object** (optional): Provides additional configuration details of the benchmark.
   
   ```json
   "config": "optional-config-object",
   ```

3. **Results Array**: An array of result objects, each representing a specific test or benchmark.
   
   ```json
   "results": [
     // Array of test objects
   ]
   ```

## Structure of a Test Object in the Results Array

Each object in the `results` array represents an individual test and should include:

- **Test Name**: The name of the specific test.
- **Metrics Array**: An array of metric objects that provide the actual benchmark data.

  ```json
  {
    "name": "name-of-the-test",
    "metrics": [
      // Array of metric objects
    ]
  }
  ```

## Structure of a Metric Object

Each metric object in the `metrics` array should contain:

- **Metric Name**: A unique identifier for the metric.
- **Value**: The benchmark result value. This can be a single number, an array, or an object, depending on the metric.
- **Units**: The unit of measurement for the metric (e.g., "ms", "ops/sec").
- **Description** (optional): A brief description of the metric.
- **Trend Indicator** (optional): Indicates whether a higher or lower value is better (e.g., "higher-is-better").

  ```json
  {
    "name": "benchmark-name",
    "value": 42,
    "units": "benchmark-unit",
    "description": "benchmark-description",
    "trend": "lower-is-better"
  }
  ```

## Full Example of a JSON Benchmark Output

Here is a simplified example of how a complete JSON output might look:

```json
{
  "name": "example-benchmark-suite",
  "config": {
    "parameter1": "value1",
    "parameter2": "value2"
  },
  "results": [
    {
      "name": "test-1",
      "metrics": [
        {
          "name": "execution-time",
          "value": 150,
          "units": "ms",
          "description": "Total execution time",
          "trend": "lower-is-better"
        },
        {
          "name": "memory-usage",
          "value": 50,
          "units": "MB",
          "description": "Memory used during execution",
          "trend": "lower-is-better"
        }
      ]
    },
    {
      "name": "test-2",
      "metrics": [
        {
          "name": "throughput",
          "value": [250, 265, 270],
          "units": "ops/sec",
          "description": "Operations per second"
        }
      ]
    }
  ]
}
```

## Groupping Metrics

By default, `current-bench` plots each metric in a separate graph. To plot multiple values in the same graph, you can use a common prefix with a slash. For instance, a group of metrics like `ocaml/parsing`, `ocaml/typing`, `ocaml/generate`, etc. will all be shown in the same graph because of the `ocaml/` prefix.

## Validating your Benchmark Results JSON

To ensure that your benchmark results JSON conforms to the schema required by current-bench, you can use the `cb-check` tool.

1. **Install `cb-check`**:
  ```
  opam pin -n cb-check \
      git+https://github.com/ocurrent/current-bench.git
  opam install cb-check
  ```

2. **Check Your Output**:
  Pipe the output of your benchmark executable to `cb-check`:
  ```
  your_executable | cb-check
  ```
  Alternatively, if your executable writes to a JSON file
  ```
  cb-check results.json
  ```
