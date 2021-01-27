.PHONY: ci
ci:
	make -C backend docker-build
	make -C backend docker-install