hooksPath := $(git config --get core.hooksPath)

export appenv := DEVELOPMENT
export TF_VAR_appenv := $(appenv)

.PHONY: precommit test deploy check lint_lambda test_lambda build_lambda release_lambda validate_terraform init_terraform apply_terraform apply_terraform_tests destroy_terraform_tests clean
test: test_lambda

deploy: build_lambda

check: precommit
ifeq ($(strip $(backend_bucket)),)
	@echo "backend_bucket must be provided"
	@exit 1
endif
ifeq ($(strip $(TF_VAR_appenv)),)
	@echo "TF_VAR_appenv must be provided"
	@exit 1
else
	@echo "appenv: $(TF_VAR_appenv)"
endif
ifeq ($(strip $(backend_key)),)
	@echo "backend_key must be provided"
	@exit 1
endif

lint_lambda: precommit
	make -C lambda lint

test_lambda: precommit
	make -C lambda test

build_lambda: precommit
	make -C lambda build

release_lambda: precommit
	make -C lambda release

validate_terraform: init_terraform
	terraform validate

init_terraform: check
	[[ -d release ]] || mkdir release
	[[ -e release/grace-ansible-lambda.zip ]] || touch release/grace-ansible-lambda.zip
	terraform init

apply_terraform: apply_terraform_tests

apply_terraform_tests:
	make -C tests apply

destroy_terraform_tests:
	make -C tests destroy

clean: precommit
	make -C lambda clean

precommit:
ifneq ($(strip $(hooksPath)),.github/hooks)
	@git config --add core.hooksPath .github/hooks
endif