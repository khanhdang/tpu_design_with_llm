# TPU with Ollama GLM 4.7 Flash

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

## One-command build with Ollama

Install OpenCode and Ollama, then prepare the local model once:

```sh
make setup
```

Set the Ollama app's context length to at least 64000 in Settings and keep it
running. Alternatively, quit the app and start the server in another terminal:

```sh
OLLAMA_CONTEXT_LENGTH=65536 ollama serve
```

Ollama's [OpenCode integration guide](https://docs.ollama.com/integrations/opencode)
requires a context window of at least 64k. A larger context uses more memory.
From this folder, run:

```sh
make build
```

The loop uses `ollama/tpu-glm-4.7-flash:64k` to implement MAC, PE, array,
controller, TPU top, and regression in order. Each stage runs in a fresh
OpenCode session with a private server using its existing prompt. The script independently runs
that stage's verification target before advancing. Failed verification feeds
its log back to the model for repair, with at most three attempts per stage.
If OpenCode fails or verification still fails, the loop exits nonzero.
Running the command again starts from MAC and follows the prompts' backup
and fresh-implementation rules. Logs are saved in a unique `sim/build.*` folder.

The unattended loop uses OpenCode's `--auto` option to approve file editing
and shell tools, subject to explicitly denied permissions. Run it from this
workspace with the local model and tools available.

```sh
BUILD_ATTEMPTS=5 make build   # Optional attempts per stage
make opencode                # Interactive session with the configured local model
```

The provider configuration follows the
[OpenCode Ollama documentation](https://opencode.ai/docs/providers/#ollama).
`LLM_MODEL` can override the configured model for either launcher.

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
opencode.json          Model-specific OpenCode configuration and commands
Makefile               Readiness, launch, simulation, and cleanup commands
docs/architecture.md   Interfaces, arithmetic, bus packing, timing, test contract
scripts/               Tool checks, OpenCode launcher, and Icarus runner
rtl/                   Generated synthesizable RTL
tb/                    Generated self-checking testbenches
sim/                   Generated simulation output
```

## Model profile

Base model: `glm-4.7-flash:latest`. Local alias: `tpu-glm-4.7-flash:64k`. The Modelfile sets
`num_ctx=65536` for this alias. MoE coding and reasoning alternative. Download size: 19 GB;
this excludes context cache and runtime overhead. No CPU speed benchmark has been run.
