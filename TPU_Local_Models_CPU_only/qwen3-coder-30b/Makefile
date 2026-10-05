.DEFAULT_GOAL := help
# Stage targets share lower-stage artifacts; serialize even with make -j.
.NOTPARALLEL:

PYTHON ?= python3
IVERILOG ?= iverilog
VVP ?= vvp
SIM_TIMEOUT ?= 30

.PHONY: help doctor doctor-opencode opencode setup build mac pe array controller tpu test regression clean

help:
	@echo "TPU workspace for cloud or local LLM assistants"
	@echo "  make doctor       Check required simulation tools (no LLM dependency)"
	@echo "  make doctor-opencode  Also check optional OpenCode and project config"
	@echo "  make opencode     Launch OpenCode; optional LLM_MODEL=provider/model"
	@echo "  make setup        Pull the model and create its 64k local alias"
	@echo "  make build        Generate and verify all stages with the configured Ollama model"
	@echo "  make mac          Verify MAC"
	@echo "  make pe           Verify MAC, then PE"
	@echo "  make array        Verify MAC, PE, then systolic array"
	@echo "  make controller   Verify through controller"
	@echo "  make tpu          Verify through TPU top"
	@echo "  make test         Run all five stages; missing stages fail"
	@echo "  make clean        Remove named simulation artifacts only"

doctor:
	$(PYTHON) scripts/check_env.py

doctor-opencode:
	$(PYTHON) scripts/check_env.py --opencode

opencode:
	bash scripts/run_opencode.sh

setup:
	bash scripts/setup_model.sh

build:
	bash scripts/run_build.sh

mac pe array controller tpu:
	IVERILOG="$(IVERILOG)" VVP="$(VVP)" SIM_TIMEOUT="$(SIM_TIMEOUT)" bash scripts/run_sim.sh $@

test regression:
	IVERILOG="$(IVERILOG)" VVP="$(VVP)" SIM_TIMEOUT="$(SIM_TIMEOUT)" bash scripts/run_sim.sh all

clean:
	$(PYTHON) scripts/simulate.py --clean
