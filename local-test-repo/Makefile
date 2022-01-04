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
	  "value": 8.02,
	  "units": "secs",
	  "description": "The total time to do awesome $$job",
	  "trend": "lower-is-better"
	},
	{
	  "name": "ops_per_sec",
	  "value": 690.0,
	  "units": "num/sec",
	  "description": "The number of awesome things done in a second",
	  "trend": "higher-is-better"
	},
	{
	  "name": "mbs_per_sec",
	  "value": 199,
	  "units": "mbps",
	  "description": "Quantity of awesome data downloaded"
	}
      ]
    },
    {
      "name": "bench_1_test_2",
      "metrics": {
	"time": "11.04secs",
	"ops_per_sec": "1455.0num/sec",
	"mbs_per_sec": "17.0mbps"
      }
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
