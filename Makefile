# https://tech.davis-hansson.com/p/make/
SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

SOURCE := $(shell find lib -name \*.ex)
TEST := $(shell find test -name \*.ex)

.PHONY: check clean

check: _build/dev _build/test
	mix test
	mix credo
	mix dialyzer
	mix docs
	mix format
	@echo "OK"

mix.lock deps: mix.exs
	mix deps.get
	mix deps.unlock --unused
	mix deps.clean --unused
	touch $@

_build/dev: deps $(SOURCE)
	MIX_ENV=dev mix compile --warnings-as-errors
	touch $@

_build/test: deps $(SOURCE) $(TEST)
	MIX_ENV=test mix compile --warnings-as-errors
	touch $@

clean:
	rm -rf _build/test/lib _build/dev/lib _build/prod/lib cover deps doc
