PROFILE ?= qwen3-coder-30b
PROFILES := qwen3-coder-30b glm-4.7-flash devstral-small-2-24b qwen3.5-9b
.NOTPARALLEL:
.PHONY: help setup build setup-all build-all doctor
help:
	@echo "make setup build PROFILE=qwen3-coder-30b  Set up and build one profile"
	@echo "make setup-all  Download all models and create their 64k aliases"
	@echo "make build-all  Build all profiles sequentially; stop on first failure"
setup build doctor:
	@case " $(PROFILES) " in *" $(PROFILE) "*) ;; *) echo "Unknown PROFILE: $(PROFILE)"; exit 1 ;; esac
	$(MAKE) -C "$(PROFILE)" $@
setup-all:
	@set -e; for profile in $(PROFILES); do $(MAKE) -C "$$profile" setup; done
build-all:
	@set -e; for profile in $(PROFILES); do $(MAKE) -C "$$profile" build; done
