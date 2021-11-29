define BENCH_DATA_1
{
  "config": null,
  "version": 2,
  "results": [
    {
      "name": "bench_1_test_1",
      "metrics": [
	{
	  "name": "time",
	  "value": 4.02,
	  "units": "secs"
	},
	{
	  "name": "ops_per_sec",
	  "value": 690.0,
	  "units": "num/sec"
	},
	{
	  "name": "mbs_per_sec",
	  "value": 199,
	  "units": "mbps"
	}
      ]
    },
    {
      "name": "bench_1_test_2",
      "metrics": [
	{
	  "name": "time",
	  "value": 10.04,
	  "units": "secs"
	},
	{
	  "name": "ops_per_sec",
	  "value": 1455.0,
	  "units": "num/sec"
	},
	{
	  "name": "mbs_per_sec",
	  "value": 17.0,
	  "units": "mbps"
	}
      ]
    }
  ]
}
endef

define BENCH_DATA_2
{
  "config": null,
  "version": 2,
  "results": [
    {
      "name": "bench_2_test_1",
      "metrics": [
	{
	  "name": "time",
	  "value": 0.01,
	  "units": "secs"
	},
	{
	  "name": "ops_per_sec",
	  "value": 50.0,
	  "units": "num/sec"
	},
	{
	  "name": "mbs_per_sec",
	  "value": 3.0,
	  "units": "mbps"
	}
      ]
    },
    {
      "name": "bench_2_test_2",
      "metrics": [
	{
	  "name": "time",
	  "value": 0.07,
	  "units": "secs"
	},
	{
	  "name": "ops_per_sec",
	  "value": 877.0,
	  "units": "num/sec"
	},
	{
	  "name": "mbs_per_sec",
	  "value": 23.0,
	  "units": "mbps"
	}
      ]
    }
  ]
}
endef

export BENCH_DATA_1
export BENCH_DATA_2
bench:
	@echo "$$BENCH_DATA_1" | jq -M .
