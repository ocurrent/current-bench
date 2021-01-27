DB_MIGRATIONS_DIR="./db/migrations"
DB_URI="postgresql://docker:docker@localhost:5432/docker"

.PHONY: db-migrate-setup
db-migrate-setup:
	omigrate setup --verbose --source=${DB_MIGRATIONS_DIR} --database=${DB_URI}

.PHONY: db-migrate-ls
db-migrate-ls:
	omigrate ls --verbose --source=${DB_MIGRATIONS_DIR} --database=${DB_URI}

.PHONY: db-migrate-up
db-migrate-up:
	omigrate up --verbose --source=${DB_MIGRATIONS_DIR} --database=${DB_URI}

.PHONY: db-migrate-down
db-migrate-down:
	omigrate down --verbose --source=${DB_MIGRATIONS_DIR} --database=${DB_URI}

.PHONY: build
build:
	dune build --profile=release bin/main.exe

.PHONY: docker-build
docker-build: _build/_docker/current-bench-pipeline
_build/_docker/current-bench-pipeline:
	export DOCKER_BUILDKIT=1 \
	docker build --target=export --output="type=local,dest=$$PWD/_build/_docker" -f build.docker .

PREFIX ?= /usr/local/bin
.PHONY: docker-install
docker-install: _build/_docker/current-bench-pipeline
	cp _build/_docker/current-bench-pipeline ${PREFIX}/current-bench-pipeline