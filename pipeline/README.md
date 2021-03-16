# OCaml Benchmarks - Pipeline

## Running the pipeline

Build the pipeline:

```# install dependencies (requires postgres, libpq-dev library)
$ opam install --deps-only .
# build
$ dune build bin/main.exe
```

Build and run the pipeline:
```
# Monitor a local Git repository:
dune exec bin/main.exe -- local "/home/user/repos/mirage/index" \
    --docker-cpu 3 \
    --conn-info "host=localhost user=docker port=5432 dbname=docker password=docker" \
    --port=8081 \
    --verbose

# Monitor a GitHub repository:
dune exec bin/main.exe -- github mirage/index \
    --github-token-file <your_github_token> \
    --oauth-user <user_github_user_name> \
    --docker-cpu 3 \
    --conn-info "host=localhost user=docker port=5432 dbname=docker password=docker" \
    --port=8081 \
    --verbose
```

You can find more options for different configurations, posting message to slack, etc by running `--help` to the pipeline executable.
