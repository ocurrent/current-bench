define BENCH_DATA_1
{
  "config": null,
  "version": 2,
  "results": [
    {
      "name": "bench_1_test_1",
      "metrics": [
	{
	  "name": "grammarFunctor/parsing",
	  "value": 0.19,
	  "units": "secs",
	  "trend": "lower-is-better"
	},
	{
	  "name": "grammarFunctor/typing",
	  "value": 0.28,
	  "units": "secs",
	  "trend": "lower-is-better"
	},
	{
	  "name": "grammarFunctor/generate",
	  "value": 0.14,
	  "units": "secs",
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

export BENCH_DATA_1
bench:
	@echo "$$BENCH_DATA_1" | jq -M .
