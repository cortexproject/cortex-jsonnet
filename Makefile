.PHONY: lint build-image publish-build-image test-readme clean

JSONNET_FMT := jsonnetfmt

# Support gsed/gfind on OSX (installed via brew), falling back to sed/find. On Linux
# systems gsed/gfind won't be installed, so will use sed/gfind as expected.
SED ?= $(shell which gsed 2>/dev/null || which sed)
FIND ?= $(shell which gfind 2>/dev/null || which find)

lint: lint-mixin lint-playbooks

lint-mixin: lint-mixin-with-mixtool lint-mixin-with-jsonnetfmt

lint-mixin-with-jsonnetfmt:
	@RESULT=0; \
	for f in $$(find . -name '*.libsonnet' -print -o -name '*.jsonnet' -print); do \
		$(JSONNET_FMT) -- "$$f" | diff -u "$$f" -; \
		RESULT=$$(($$RESULT + $$?)); \
	done; \
	exit $$RESULT

lint-mixin-with-mixtool:
	cd cortex-mixin && \
	jb install && \
	mixtool lint mixin.libsonnet

lint-playbooks: build-mixin
	@./scripts/lint-playbooks.sh

fmt:
	@find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNET_FMT) -i

build-image:
	docker build -t quay.io/cortexproject/cortex-jsonnet-build-image:$(shell git rev-parse --short HEAD) build-image

save-build-image:
	docker save quay.io/cortexproject/cortex-jsonnet-build-image:$(shell git rev-parse --short HEAD) > build-image.tar

load-build-image:
	docker load < build-image.tar

publish-build-image:
	docker push quay.io/cortexproject/cortex-jsonnet-build-image:$(shell git rev-parse --short HEAD)

build-mixin:
	@cd cortex-mixin && \
	rm -rf out && mkdir out && \
	jb install && \
	mixtool generate all --output-alerts out/alerts.yaml --output-rules out/rules.yaml --directory out/dashboards mixin.libsonnet && \
	zip -q -r cortex-mixin.zip out

test-readme: test-readme/azure test-readme/gcs test-readme/s3

test-readme/%:
	@./scripts/test-readme.sh $@

clean-white-noise:
	@$(FIND) . -type f -regextype posix-extended -regex '.*(md|libsonnet)' -print | \
	SED_BIN="$(SED)" xargs ./scripts/cleanup-white-noise.sh

check-white-noise: clean-white-noise
	@git diff --exit-code --quiet || (echo "Please remove trailing whitespaces running 'make clean-white-noise'" && false)

clean:
	rm -rf cortex-mixin/out
	rm -rf cortex-mixin/vendor
	rm -f cortex-mixin/cortex-mixin.zip
	rm -rf test-readme
