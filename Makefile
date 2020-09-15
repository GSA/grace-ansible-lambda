hooksPath := $(git config --get core.hooksPath)

export appenv := DEVELOPMENT
export TF_VAR_appenv := $(appenv)
GOBIN := $(GOPATH)/bin
TFSEC := $(GOBIN)/tfsec

.PHONY: precommit test deploy check lint_lambda test_lambda build_lambda release_lambda validate_terraform init_terraform apply_terraform apply_terraform_tests destroy_terraform_tests clean
test: test_lambda validate_terraform build_rotate_keypair

deploy: build_lambda build_rotate_keypair

check: precommit
ifeq ($(strip $(TF_VAR_appenv)),)
	@echo "TF_VAR_appenv must be provided"
	@exit 1
else
	@echo "appenv: $(TF_VAR_appenv)"
endif

lint_lambda: precommit
	make -C lambda lint

test_lambda: precommit
	make -C lambda test

build_lambda: precommit
	make -C lambda build

release: precommit clean build_rotate_keypair
	make -C lambda release

lint_rotate_keypair: precommit
	make -C rotate_keypair lint

test_rotate_keypair: precommit
	make -C rotate_keypair test

build_rotate_keypair: precommit
	make -C rotate_keypair build

validate_terraform: init_terraform $(TFSEC)
	terraform validate
	$(TFSEC)

init_terraform: check
	[[ -d release ]] || mkdir release
	[[ -e release/grace-ansible-lambda.zip ]] || touch release/grace-ansible-lambda.zip
	terraform init
	terraform fmt

apply_terraform: apply_terraform_tests

apply_terraform_tests:
	make -C tests apply

destroy_terraform_tests:
	make -C tests destroy

clean: precommit
	rm -rf release

precommit:
ifneq ($(strip $(hooksPath)),.github/hooks)
	@git config --add core.hooksPath .github/hooks
endif

$(TFSEC):
	go get -u github.com/liamg/tfsec/cmd/tfsec
