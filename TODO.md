
# benchmarks
- ppx that runs over a module containing all of the benchmarks and generates all
  the runners / types (source location referencing? hashing of source?)
- must be versioned for backwards-compatibility (each one contains an int?),
  would be nicely fixed by ppx
- should expose CLI options for benchmark size (which can then be exposed by the
  runner too)

# frontend
- fix all d3 dependencies being pulled in at once
- fix lifecycle hooks with React so that graphs load correctly
- extract Backend.re to interact with an Irmin GraphQL store
- show message of latest commit as well as hash (store this in the Irmin store?
  other metadata such as source location?)
- setup refmt
- ci to check that it builds / linting
- show changes that broke compatibility (different AST hash) as dotted lines?

# runner
- have a Current_cli trigger for the benchmark that runs a single time and
  submits a result

# database
- track standard deviation of data via aggregating over duplicate submissions
- multiple data sources for the Irmin store should merge gracefully
- UIDs to track duplicate submissions of the same data by
- GraphQL streaming to send live data to the front-end?
- security?

# ocurrent
- have 'disable-able' stages where the disabling trigger is known to be given by
  another stage. This would be useful for optional behaviours triggered by
  run-time flags (such as submission of values to Slack)

```
          .---------.                .---------.
--------->|         |--------------> | toggled |------------
          `---------'                `---------'
               |                         / \
               |       .---------.        |
               |-------| trigger |- - - - |
                       `---------'
```


# irmin
- finite trees of known type at both the top _and_ the bottom (infinite and
  homogeneous in the middle), allows file extensions to be the final step in the
  path, determining the type for that use-case
