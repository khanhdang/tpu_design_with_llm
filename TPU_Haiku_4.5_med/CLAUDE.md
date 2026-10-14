# TPU Haiku 4.5 Medium Design Project

A staged SystemVerilog TPU (Tensor Processing Unit) implementation for 4×4 matrix multiplication using a systolic array architecture.

## Project Status
- **Environment**: ✅ Ready (Python 3.9+, make, bash, iverilog, vvp)
- **Implementation Status**: Empty rtl/ and tb/ directories, ready for staged development
- **Current Stage**: None (start with MAC)

## Architecture Overview
- **Design**: 4×4 systolic array for signed INT8 matrix multiplication
- **Default Parameters**: DATA_WIDTH=8, ACC_WIDTH=32, ARRAY_SIZE=4
- **Matrix Operation**: C = A × B (4×4 × 4×4 → 4×4)

## Staged Implementation Pipeline

Implement **in order** – do not proceed to the next stage until the current stage passes its test:

1. **MAC** (Multiply-Accumulate) – `make mac`
   - File: `rtl/mac.sv`, `tb/mac_tb.sv`
   - Prompt: `prompts/mac.md`

2. **PE** (Processing Element) – `make pe`
   - File: `rtl/pe.sv`, `tb/pe_tb.sv`
   - Prompt: `prompts/pe.md`

3. **Systolic Array** – `make array`
   - File: `rtl/systolic_array.sv`, `tb/systolic_array_tb.sv`
   - Prompt: `prompts/array.md`

4. **Controller** – `make controller`
   - File: `rtl/controller.sv`, `tb/controller_tb.sv`
   - Prompt: `prompts/controller.md`

5. **TPU Top** – `make tpu`
   - File: `rtl/tpu_top.sv`, `tb/tpu_top_tb.sv`
   - Prompt: `prompts/tpu.md`

6. **Regression** – `make test`
   - Prompt: `prompts/regression.md`

## Key Files & Documentation

| File | Purpose |
|------|---------|
| `AGENTS.md` | Strict rules for RTL coding, testbench requirements, and workflow |
| `docs/architecture.md` | Module interfaces, timing, transaction flow, packed matrix layout |
| `Makefile` | Test targets and environment variables |
| `prompts/` | Stage-specific implementation instructions |
| `rtl/` | Generated SystemVerilog RTL (empty, ready for implementation) |
| `tb/` | Generated self-checking testbenches (empty, ready for implementation) |
| `sim/` | Simulation logs, waveforms, and restart backups |

## Required Workflow (From AGENTS.md)

For each stage:
1. **Read** `AGENTS.md`, `docs/architecture.md`, and `Makefile` before coding
2. **Implement** the RTL (.sv) and testbench (.sv) files
3. **Compile** with `iverilog -g2012 -Wall`
4. **Run simulation** with `vvp`
5. **Verify** output has exactly one test summary line
6. **Fix** any failures and rerun until PASS
7. **Report** final results before moving to next stage

### Critical Testbench Rules
- **Self-checking**: Calculate expected values independently
- **Error tracking**: Maintain error and test counters
- **Output verification**: Use `!==` to catch unknown values
- **Bounded watchdog**: Include timeout protection
- **Final summary** (required exact format):
  ```
  ========================================
  <MODULE> TEST RESULT: PASS (or FAIL)
  Tests: <actual count>
  Errors: <actual count>
  ========================================
  ```
- **Exit**: Use `$finish` after printing summary

### Critical RTL Rules
- **Synthesizable only** – no #delay, no testbench constructs in RTL
- **Nonblocking assignments** for sequential logic
- **Parameters** for DATA_WIDTH, ACC_WIDTH, ARRAY_SIZE
- **No DSP/AXI/external memory** required
- **Use `.sv`** for new files

## Commands

```bash
# Check environment (must pass before starting)
make doctor

# Run individual stages
make mac              # Compile and test MAC only
make pe               # Run MAC, then PE
make array            # Through systolic array
make controller       # Through controller
make tpu              # Through TPU top
make test             # Full five-stage regression

# Options
make test SIM_TIMEOUT=60  # Increase timeout to 60 seconds per stage
make clean               # Remove sim artifacts (not source)
```

## Simulation Output

- **Compile logs**: `sim/<module>_compile.log`
- **Runtime logs**: `sim/<module>_run.log`
- **Waveforms** (optional): `sim/<module>_tb.vcd`
- **Restart backups**: `sim/restart-backup/` (created by stage prompts)

## Success Criteria

- ✅ Each stage compiles without errors
- ✅ Simulation runs to completion (no timeout)
- ✅ Final summary shows `PASS` with `Errors: 0` and `Tests > 0`
- ✅ All stages pass in order before declaring completion

## Getting Started

1. Give the assistant `prompts/mac.md` (first stage)
2. Assistant reads AGENTS.md, docs/architecture.md, and Makefile
3. Assistant creates `rtl/mac.sv` and `tb/mac_tb.sv`
4. Assistant runs `make mac` and fixes failures until PASS
5. Repeat for PE, systolic array, controller, TPU top, regression

For questions about architecture or interfaces, consult `docs/architecture.md` directly.
