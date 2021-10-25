define BENCH_DATA_1
{
  "config": {
  },
  "version": 2,
  "results": [
    {
      "name": "bench_1_test_1",
      "metrics": [
	{
	  "name": "time",
	  "value": 4.02
	},
	{
	  "name": "ops_per_sec",
	  "value": 690.0
	},
	{
	  "name": "mbs_per_sec",
	  "value": 199
	}
      ]
    },
    {
      "name": "bench_1_test_2",
      "metrics": [
	{
	  "name": "time",
	  "value": 10.04
	},
	{
	  "name": "ops_per_sec",
	  "value": 1455.0
	},
	{
	  "name": "mbs_per_sec",
	  "value": 17.0
	}
      ]
    }
  ]
}
endef

define BENCH_DATA_2
{
  "config": {  },
  "results": [
    {
      "name": "bench_2_test_1",
      "metrics": [
	{
	  "name": "time",
	  "value": 0.01
	},
	{
	  "name": "ops_per_sec",
	  "value": 50.0
	},
	{
	  "name": "mbs_per_sec",
	  "value": 3.0
	}
      ]
    },
    {
      "name": "bench_2_test_2",
      "metrics": [
	{
	  "name": "time",
	  "value": 0.07
	},
	{
	  "name": "ops_per_sec",
	  "value": 877.0
	},
	{
	  "name": "mbs_per_sec",
	  "value": 23.0
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
