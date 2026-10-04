# TPU development template

Use a cloud or local LLM assistant to implement a small signed matrix-multiplication
TPU in SystemVerilog. Configure the assistant and its model in your preferred
client. This folder contains the project instructions and verification tools.
The `rtl/` and `tb/` folders start empty; generate and verify one stage at a time.

## Run

Install Icarus Verilog (`iverilog` and `vvp`), make, Bash, and Python 3.9 or later.
On macOS, install the simulator with `brew install icarus-verilog`.

```sh
make doctor
```

Give your assistant [AGENTS.md](AGENTS.md), [docs/architecture.md](docs/architecture.md),
and `Makefile`. Start with the MAC prompt listed in [prompts.md](prompts.md).
An assistant with file-editing and shell tools can work directly in this folder.
For a chat-only model, apply its files locally, run the verification command,
and return the actual logs for correction.

Proceed in order: MAC, PE, systolic array, controller, TPU top, then regression.
Each stage must pass its executed simulation before the next begins.

## OpenCode

If you use OpenCode, configure your cloud or local provider in the client and run:

```sh
make opencode
# In OpenCode: /mac, then /pe, /array, /controller, /tpu, /regression
```

The project config loads the architecture and the same files under `prompts/`.
It leaves model selection to your personal settings or client selection.
To choose a model for one launch:

```sh
LLM_MODEL='provider/model-id' make opencode
```

The launcher preserves personal `OPENCODE_CONFIG` overlays and passes through
OpenCode CLI arguments. An explicit `--model` or `-m` overrides `LLM_MODEL`.

## Verification

```sh
make mac                 # MAC only
make pe                  # MAC, then PE
make array               # Through systolic array
make controller          # Through controller
make tpu                 # Through TPU top
make test                # Complete five-stage regression
make test SIM_TIMEOUT=60 # Seconds allowed per vvp process; default 30
make clean               # Remove named simulation artifacts
```

The runner uses `iverilog -g2012 -Wall` with an explicit testbench top, then `vvp`.
It rejects missing source files, compilation/runtime failures, timeouts, invalid
summaries, and zero-check tests. Logs and optional waveforms go in `sim/`.
Until the stages are implemented, `make test` fails on missing MAC sources.

## Files

```text
AGENTS.md              Assistant rules and required verification workflow
README.md              Setup and usage
prompts.md             Stage index and instructions
prompts/               One prompt file per stage, shared by all clients
opencode.json          Model-neutral OpenCode command registration
Makefile               Readiness, launch, simulation, and cleanup commands
docs/architecture.md   Interfaces, arithmetic, bus packing, timing, test contract
scripts/               Tool checks, OpenCode launcher, and Icarus runner
rtl/                   Generated synthesizable RTL
tb/                    Generated self-checking testbenches
sim/                   Generated simulation output
```
