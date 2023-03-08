define BENCH_DATA_B1_T1_A
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
	}
      ]
    }
  ]
}
endef

define BENCH_DATA_B1_T1_B
{
  "config": null,
  "version": 2,
  "results": [
    {
      "name": "bench_1_test_1",
      "metrics": [
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
    }
  ]
}
endef

define BENCH_DATA_B1_T2
{
  "config": null,
  "version": 1,
  "results": [
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

define BENCH_DATA_3
{""}
endef

export BENCH_DATA_B1_T1_A
export BENCH_DATA_B1_T1_B
export BENCH_DATA_B1_T2
export BENCH_DATA_3
bench:
	echo "Log message 1"
	echo "Log message 2"
	@echo "$$BENCH_DATA_B1_T1_A" | jq -M .
	echo "Log message 3"
	@echo "$$BENCH_DATA_B1_T1_B" | jq -M .
	echo "Log message 4"
	echo "Log message 5"
	@echo "$$BENCH_DATA_B1_T2" | jq -M .
	echo "Log message 6"
	echo "Log message 7"
	@echo "$$BENCH_DATA_3"
