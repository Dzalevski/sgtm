GOPKG ?=	moul.io/sgtm
DOCKER_IMAGE ?=	moul/sgtm
GOBINS ?=	./cmd/sgtm

PRE_INSTALL_STEPS += gen.sum
PRE_UNITTEST_STEPS += gen.sum
PRE_TEST_STEPS += gen.sum
PRE_BUILD_STEPS += gen.sum
PRE_LINT_STEPsS += gen.sum
PRE_TIDY_STEPS += gen.sum
PRE_BUMPDEPS_STEPS += gen.suma

include rules.mk


.PHONY: run
run: install
	sgtm --dev-mode --enable-server --enable-discord run

.PHONY: run-discord
run-discord: install
	sgtm --dev-mode --enable-discord run

.PHONY: run-server
run-server: install
	sgtm --dev-mode --enable-server run

.PHONY: packr
packr:
	(cd static; git clean -fxd)
	packr2

.PHONY: deploy
deploy: docker.push
	ssh zrwf.m.42.am make -C infra/projects/sgtm.club re

.PHONY: prod-logs
prod-logs:
	ssh zrwf.m.42.am make -C infra/projects/sgtm.club logs

.PHONY: docker.push
docker.push: tidy generate docker.build
	docker push $(DOCKER_IMAGE)

PROTOS_SRC := $(wildcard ./api/*.proto)
GEN_DEPS := $(PROTOS_SRC) Makefile
.PHONY: generate
generate: gen.sum
gen.sum: $(GEN_DEPS)
	shasum $(GEN_DEPS) | sort > gen.sum.tmp
	@diff -q gen.sum gen.sum.tmp || ( \
	  set -xe; \
	  GO111MODULE=on go mod vendor; \
	  docker run \
	    --user=`id -u` \
	    --volume="$(PWD):/go/src/moul.io/sgtm" \
	    --workdir="/go/src/moul.io/sgtm" \
	    --entrypoint="sh" \
	    --rm \
	    moul/moul-bot-protoc:1 \
	    -xec 'make generate_local'; \
	    make tidy \
	)
	@rm -f gen.sum.tmp

PROTOC_OPTS = -I ./api:/protobuf
.PHONY: generate_local
generate_local:
	@set -e; for proto in $(PROTOS_SRC); do ( set -xe; \
	  protoc $(PROTOC_OPTS) \
	    --grpc-gateway_out=logtostderr=true:"$(GOPATH)/src" \
	    --go_out="$(GOPATH)/src" \
	    --go-grpc_out="$(GOPATH)/src" \
	    "$$proto" \
	); done
	goimports -w ./pkg ./cmd ./internal
	shasum $(GEN_SRC) | sort > gen.sum.tmp
	mv gen.sum.tmp gen.sum

.PHONY: clean
clean:
	rm -f gen.sum $(wildcard */*/*.pb.go */*/*.pb.gw.go)
	@# packr
