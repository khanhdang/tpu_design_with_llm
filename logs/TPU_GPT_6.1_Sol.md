# Build TPU project

> check this folder and build

<details><summary>11 previous messages</summary>

> I’ll inspect the project instructions, source files, and Makefile, then run the Icarus verification stages in order and fix any build or simulation failures.
>
> The folder is a TPU template: `rtl/` and `tb/` are empty. The required tools are installed, and `make mac` fails because its sources are missing. I’ll implement and verify the five stages one at a time, following the documented interfaces and timing.
>
> <details><summary>Created 2 files</summary>
>
> - Wrote `./rtl/mac.sv` (+19 -0)
> - Wrote `./tb/mac_tb.sv` (+80 -0)
>
> </details>
>
> MAC passed 1,548 checks with zero errors and no compiler warnings. Its tests cover signed extrema, hold/clear/reset priority, randomized operations, 16-bit accumulator wraparound, and 4-bit inputs. I’m moving to the PE stage.
>
> <details><summary>Created 4 files</summary>
>
> - Wrote `./rtl/pe.sv` (+19 -0)
> - Wrote `./tb/pe_tb.sv` (+86 -0)
> - Wrote `./rtl/systolic_array.sv` (+28 -0)
> - Wrote `./tb/systolic_array_tb.sv` (+140 -0)
>
> </details>
>
> PE passed 4,635 checks, and the systolic array passed 19,207 checks, both with zero errors and no warnings. The array tests check every accumulator at each compute step, including stalls, reset/clear recovery, random matrices, and 1×1, 2×2, and 4×4 configurations. Next is controller timing.
>
> <details><summary>Created 2 files</summary>
>
> - Wrote `./rtl/controller.sv` (+36 -0)
> - Wrote `./tb/controller_tb.sv` (+120 -0)
>
> </details>
>
> The controller passed 25,722 checks with zero errors and no warnings. Tests confirm the 1, 4, and 10 compute-edge schedules, ignored requests while busy, completion pulses, consecutive transactions, and reset aborts. I’m now integrating the top level and testing matrix results, input latching, and result retention.
>
> <details><summary>Created 2 files</summary>
>
> - Wrote `./rtl/tpu_top.sv` (+49 -0)
> - Wrote `./tb/tpu_top_tb.sv` (+167 -0)
>
> </details>
>
> The top-level simulation passed 103,341 checks with zero errors and no warnings. Each configuration completed 60 fixed-seed random matrix pairs, with every output element checked against an independent signed matrix calculation. Input changes after acceptance, busy requests, reset aborts, and result retention also passed. I’ll update the README and run the required final `make test` regression.
>
> <details><summary>Edited a file</summary>
>
> - Wrote `./README.md` (+34 -9)
>
> </details>
</details>

Built the TPU from the empty template: added five RTL modules, five self-checking testbenches, and updated [README.md](./README.md).

Ran `make mac`, `make pe`, `make array`, `make controller`, `make tpu`, then `make test` using Icarus Verilog. Final regression exited **0**.

| Stage | Result | Checks | Errors |
|---|---|---:|---:|
| MAC | PASS | 1,548 | 0 |
| PE | PASS | 4,635 | 0 |
| Systolic array | PASS | 19,207 | 0 |
| Controller | PASS | 25,722 | 0 |
| TPU top | PASS | 103,341 | 0 |

No compiler warnings. Coverage includes signed arithmetic, overflow, reset/control timing, deterministic and fixed-seed random matrix products, and N=1/2/4 configurations with non-default widths. Parameters and seeds are documented in the README.

Logs and the [TPU waveform](./sim/tpu_top_tb.vcd) are in `sim/`. Synthesis and hardware execution remain unverified.
