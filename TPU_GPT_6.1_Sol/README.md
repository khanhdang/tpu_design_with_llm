# Small systolic TPU

This project implements a small signed matrix-multiplication TPU in SystemVerilog.
The five RTL modules in `rtl/` have self-checking Icarus testbenches in `tb/`.
The default configuration multiplies two 4 × 4 matrices with signed 8-bit inputs
and 32-bit accumulators. Interfaces and timing are defined in
[docs/architecture.md](docs/architecture.md).

## Run

Install Icarus Verilog (`iverilog` and `vvp`), make, Bash, and Python 3.9 or later.
On macOS, install the simulator with `brew install icarus-verilog`.

```sh
make doctor
make test
```

Give your assistant [AGENTS.md](AGENTS.md), [docs/architecture.md](docs/architecture.md),
and `Makefile` when modifying the design. Stage implementation prompts are listed
in [prompts.md](prompts.md).
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
Missing stage sources are failures.

The regression checks signed arithmetic, overflow wrapping, control priorities,
PE forwarding, array skew/stalls, controller timing, input latching, published
result retention, busy requests, reset aborts, and consecutive transactions.
Every matrix output element is compared with an independent signed nested-loop
reference. The array bench runs 24 random pairs per configuration; the TPU bench
runs 60 per configuration in addition to directed and transaction-control tests.

Tested parameter configurations (DATA_WIDTH / ACC_WIDTH):

| Stage | Configurations | Fixed seed values (hexadecimal) |
| --- | --- | --- |
| MAC | 8/32, 8/16, 4/12 | 4d414301, 4d414302, 4d414303 |
| PE | 8/32, 8/16, 5/16 | 50450001, 50450002, 50450003 |
| Array | N=4 8/32, N=1 8/16, N=2 5/16, N=4 8/16 | 41525201, 41525202, 41525203, 41525204 |
| Controller | N=4, N=1, N=2 | 43545201, 43545202, 43545203 |
| TPU top | N=4 8/32, N=1 8/16, N=2 5/16, N=4 8/16 | 54505501, 54505502, 54505503, 54505504 |

Each testbench has a cycle watchdog, prints actual check/error counts, and reports
the seed on randomized mismatches. The top bench writes `sim/tpu_top_tb.vcd`.
Verification covers RTL simulation; synthesis, timing closure, FPGA/ASIC hardware,
and parameter combinations beyond those above have not been verified.

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
rtl/                   Five synthesizable SystemVerilog modules
tb/                    Five self-checking SystemVerilog testbenches
sim/                   Generated simulation output
```
