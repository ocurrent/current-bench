.PHONY: start-production
start-production: update-version-info validate-env
	./scripts/prod.sh up --detach --build

.PHONY: build-production
build-production:
	./scripts/prod.sh build

.PHONY: stop-production
stop-production:
	./scripts/prod.sh down

.PHONY: redeploy-production
redeploy-production: \
	build-production \
	stop-production \
	start-production

# Validate docker-compose env files
.PHONY: validate-env
validate-env:
	./scripts/validate-env.sh

# Make sure the fake testing repo is initialised.
./local-repos/test/.git:
	cd ./local-repos/test/ && git init && git add . && git commit -m "Initial commit."

# Update current bench version
.PHONY: update-version-info
update-version-info:
	./scripts/version.sh

# Clean the fake testing repo
.PHONY: clean-local-test-repo
clean-local-test-repo:
	cd ./local-repos/test/ && rm -rf .git/

.PHONY: start-development
start-development: ./local-repos/test/.git update-version-info validate-env
	./scripts/dev.sh up --remove-orphans --build

.PHONY: stop-development
stop-development: ./local-repos/test/.git
	./scripts/dev.sh down

.PHONY: update-graphql-schema
update-graphql-schema: ./local-repos/test/.git
	./scripts/dev.sh exec frontend /app/scripts/update-graphql-schema.sh


.PHONY: rebuild-pipeline
rebuild-pipeline: ./local-repos/test/.git
	./scripts/dev.sh up --detach --build pipeline

.PHONY: rebuild-frontend
rebuild-frontend: ./local-repos/test/.git
	./scripts/dev.sh up --detach --build frontend

.PHONY: bench
bench:
	@cd ./local-repos/test/ && make -s bench

.PHONY: start-prometheus-alertmanager
start-prometheus-alertmanager:
	cd ./prometheus/ && \
	docker-compose --env-file=../environments/production.env up --detach

.PHONY: stop-prometheus-alertmanager
stop-prometheus-alertmanager:
	cd ./prometheus/ && \
	docker-compose --env-file=../environments/production.env down

.PHONY: start-node-exporter
start-node-exporter:
	./prometheus/scripts/start-node-exporter.sh --web.listen-address 0.0.0.0:10080

.PHONY: runtest
runtest: ./local-repos/test/.git
	./scripts/dev.sh \
		exec pipeline bash -c 'cd /mnt/project; opam exec -- dune runtest'

.PHONY: coverage
coverage: ./local-repos/test/.git
	./scripts/dev.sh \
		exec pipeline bash -c \
		'cd /mnt/project; opam exec -- dune runtest --instrument-with bisect_ppx --force; \
		opam exec -- bisect-ppx-report summary --per-file; opam exec -- bisect-ppx-report html' \
	&& echo "To view coverage html open file://${PWD}/pipeline/_coverage/index.html in your browser"

.PHONY: local-make-bench
local-make-bench: ./local-repos/test/.git
	cd local-repos/test/; git add .; git commit --amend -m "New commit: $$(date)"; cd ..

.PHONY: migration
migration:
	./scripts/dev.sh \
		exec pipeline omigrate create --verbose --dir=/app/db/migrations $(NAME)
