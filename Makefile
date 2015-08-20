REBAR := ./rebar --config rebar_test_build.config

.PHONY: \
	all \
	clean_all \
	clean_app \
	compile_all \
	compile_app \
	deps \
	deps_get \
	deps_update \
	dialyze \
	dialyzer_blt_build \
	test

all: \
	clean_all \
	deps_get \
	compile_all \
	dialyze \
	test

deps_get:
	@$(REBAR) get-deps

deps_update:
	@$(REBAR) update-deps

deps: \
	deps_get \
	deps_update

compile_all:
	$(REBAR) compile skip_deps=false

compile_app:
	$(REBAR) compile skip_deps=true

clean_all:
	$(REBAR) clean skip_deps=false

clean_app:
	$(REBAR) clean skip_deps=true

dialyze:
	@dialyzer deps/*/ebin ebin

dialyzer_blt_build:
	@dialyzer \
		--build_plt \
		--apps $(shell ls $(shell \
			erl -eval 'io:format(code:lib_dir()), init:stop().' -noshell) \
			| grep -v interface \
			| sed -e 's/-[0-9.]*//' \
		)

test:
	@$(REBAR) ct skip_deps=true --verbose=1
