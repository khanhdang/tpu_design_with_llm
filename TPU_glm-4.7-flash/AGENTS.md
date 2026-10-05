# AGENTS.md

## Project

This project implements a small TPU accelerator using Verilog/SystemVerilog.

Read `docs/architecture.md` before coding; it defines module interfaces,
signed arithmetic, bus packing, and cycle timing. `README.md` documents setup.
The selected LLM is a development assistant and may run locally or in the
cloud. This small TPU implements matrix multiplication; do not add full LLM
inference or a model-serving hardware backend.
These rules apply regardless of the assistant, provider, or model. If your
client does not load AGENTS.md automatically, include it in the task context.
Work directly in the project files. Keep each task focused on one verification
stage, and report actual tool results rather than predicted results.

RTL source files are located in:

    rtl/

Testbenches are located in:

    tb/

Simulation output files must be placed in:

    sim/

## Simulator

Use Icarus Verilog for all RTL simulation.

Compile SystemVerilog using:

    iverilog -g2012

Run the compiled simulation using:

    vvp

Do not use Verilator, ModelSim, Vivado Simulator, or other simulators
unless explicitly requested.

## Simulation Workflow

For each RTL module, compile the RTL together with its corresponding
testbench.

Read Makefile to know how to run.

Use `make mac`, `make pe`, `make array`, `make controller`, and `make tpu`
in that order. Higher targets rerun all lower stages before continuing.
Use `make test` for the complete regression. Missing source files are failures,
not skipped tests. New sources use `.sv`; module and testbench names must match
the stage table in `docs/architecture.md`. The runner selects the testbench
top explicitly and uses `iverilog -g2012 -Wall`, then `vvp`.
Logs are `sim/<module>_compile.log` and `sim/<module>_run.log`.


## Required Agent Workflow

Whenever RTL or a testbench is created or modified:

1. Compile the design with Icarus Verilog.
2. Read all compiler warnings and errors.
3. Fix compilation errors before continuing.
4. Run the simulation using `vvp`.
5. Inspect the simulation output.
6. If the test fails, determine whether the problem is in the RTL or
   testbench.
7. Fix the problem.
8. Compile and simulate again.
9. Repeat until all tests pass.
10. Report the final simulation result.

Do not claim that the implementation works unless the simulation has
actually been executed successfully.

## Testbench Requirements

Testbenches must be self-checking.

Each testbench must:

- Generate clock and reset.
- Apply input stimuli.
- Calculate or contain known expected results.
- Compare DUT outputs against expected outputs.
- Print useful information when a comparison fails.
- Maintain an error counter.
- Count executed checks; zero-check tests are not passing tests.
- Compare using case inequality (`!==`) to catch unknown values.
- Include a bounded watchdog and reproducible randomized stimuli where useful.
- Print `PASS` when all tests succeed.
- Print `FAIL` when one or more tests fail.
- Finish using `$finish`.

Use the exact module-specific final summary described in `docs/architecture.md`.
The simulation runner rejects FAIL/FATAL/ERROR output, missing or inconsistent
summaries, nonzero process exits, and wall-clock timeouts. Never remove these
checks, reduce coverage, or change expected values simply to obtain PASS.

Example final result:

    ========================================
    TPU_TOP TEST RESULT: PASS
    Tests: 100
    Errors: 0
    ========================================

A failed test should report enough information for debugging, for example:

    FAIL C[2][3]: expected=127 got=125

## Waveforms

Testbenches should generate VCD waveforms when useful:

    initial begin
        $dumpfile("sim/tpu_top_tb.vcd");
        $dumpvars(0, testbench_name);
    end

Do not attempt to use GTKWave automatically unless explicitly requested.

## RTL Requirements

RTL must be synthesizable.

Use synchronous sequential logic where appropriate.

Avoid:

- `#delay` in synthesizable RTL
- unsynthesizable loops
- testbench constructs inside RTL
- unnecessary vendor-specific primitives

`#delay` is allowed in testbenches.

Use parameters for configurable values such as:

    DATA_WIDTH
    ACC_WIDTH
    ARRAY_SIZE

## Verification Strategy

Develop and verify the TPU incrementally:

    MAC
     ↓
    PE
     ↓
    Systolic Array
     ↓
    Controller
     ↓
    TPU Top

Do not proceed to a higher-level module until the lower-level module
passes its testbench.

For each stage, run its Makefile target, inspect every warning and failure,
and summarize files changed, executed checks, errors, and remaining limitations.
Stop after the requested stage. `prompts.md` lists the portable staged prompts
in `prompts/`; OpenCode commands load these same files.
Before final completion, run `make test` and check every output element for
deterministic and randomized matrix products. Do not claim full TPU completion
while any stage is missing or fails.
