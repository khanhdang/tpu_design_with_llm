# Build TPU project

> check this folder and build

<details><summary>38 previous messages</summary>

> I’ll take a pass through the project structure and the required docs first, then I’ll build using the Makefile workflow from the repo. After that I’ll report the actual compile/sim results rather than guessing.
>
> <details><summary>Explored 3 files, ran a command</summary>
>
> <details><summary>Explored 2 files</summary>
>
> - Read `./docs/architecture.md`
> - Read `./README.md`
>
> </details>
>
> - Ran `pwd && rg --files`
>
> <details><summary>Explored a file</summary>
>
> - Read `./Makefile`
>
> </details>
>
> </details>
>
> The repo is a template right now: the required `rtl/` and `tb/` stage files are not present in the file list. I’m going to run the environment check and the regression target next so we have the real build failure in hand before deciding whether to generate the stages.
>
> <details><summary>Ran 2 commands</summary>
>
> - Ran `make doctor`
> - Ran `make test`
>
> </details>
>
> Environment is good, but `make test` stops immediately because `rtl/mac.sv`/`tb/mac_tb.sv` are missing. Since the folder is a staged TPU template, I’m going to fill in the RTL and self-checking benches in the required order, then compile and simulate each stage through `make test`.
>
> <details><summary>Explored 4 files</summary>
>
> - Read `./scripts/simulate.py`
> - Read `./prompts/mac.md`
> - Read `./scripts/run_sim.sh`
> - Read `./prompts/tpu.md`
>
> </details>
>
> The simulation runner is strict in a useful way: explicit source lists, explicit tops, and log parsing for `PASS`, positive test counts, and zero errors. I’m reading the remaining staged prompts now so the implementation and benches line up with the expected coverage instead of just the bare interfaces.
>
> <details><summary>Explored 4 files</summary>
>
> - Read `./prompts/regression.md`
> - Read `./prompts/controller.md`
> - Read `./prompts/pe.md`
> - Read `./prompts/array.md`
>
> </details>
>
> I have enough context now. I’m going to create the five RTL modules plus their self-checking benches, keeping the design contracts exactly as documented: signed products, packed row-major buses, synchronous reset, and the controller’s clear/run/capture timing.
>
> <details><summary>Ran 2 commands</summary>
>
> - Ran `mkdir -p rtl tb sim`
> - Ran `git status --short`
>
> </details>
>
> I’m starting with the RTL, because once those interfaces are stable the benches can exercise them stage by stage. The controller and top are the timing-sensitive parts; the lower MAC/PE/array modules are intentionally small and parameterized.
>
> <details><summary>Created 5 files</summary>
>
> - Wrote `./rtl/controller.sv` (+76 -0)
> - Wrote `./rtl/mac.sv` (+31 -0)
> - Wrote `./rtl/pe.sv` (+40 -0)
> - Wrote `./rtl/systolic_array.sv` (+51 -0)
> - Wrote `./rtl/tpu_top.sv` (+98 -0)
>
> </details>
>
> One small defensive RTL adjustment before the benches: the MAC has to support `ACC_WIDTH == 2*DATA_WIDTH`, so I’m avoiding a zero-width sign-extension replication for that parameter case.
>
> <details><summary>Edited a file</summary>
>
> - Wrote `./rtl/mac.sv` (+8 -1)
>
> </details>
>
> I’m adding the MAC and PE benches first and will run `make mac`/`make pe` immediately after those files exist. That keeps the verification ladder honest before I move up into the array.
>
> <details><summary>Created 2 files</summary>
>
> - Wrote `./tb/mac_tb.sv` (+172 -0)
> - Wrote `./tb/pe_tb.sv` (+187 -0)
>
> </details>
>
> MAC and PE benches are in place. I’m compiling and simulating those two stages now so any syntax or timing mismatch gets caught before I build higher-level tests on top of it.
>
> <details><summary>Ran a command</summary>
>
> - Ran `make pe`
>
> </details>
>
> The lower stages are clean: `make pe` reran MAC and PE with 228 and 178 checks, no errors. Next I’m adding the systolic-array bench with default, `N=2`, and `N=1` instances plus skewed-lane matrix products.
>
> <details><summary>Created a file</summary>
>
> - Wrote `./tb/systolic_array_tb.sv` (+455 -0)
>
> </details>
>
> The array testbench is ready. I’m running `make array` now; this will rerun MAC and PE, then compile/simulate the systolic array with the new skewed-input checks.
>
> <details><summary>Ran a command</summary>
>
> - Ran `make array`
>
> </details>
>
> Array simulation passed with 853 checks. I’m moving to the controller now, where the bench will focus on phase timing: idle accept, one clear edge, exact compute counts for `N=1/2/4`, capture, one-cycle done, ignored busy starts, reset abort, and consecutive transactions.
>
> <details><summary>Created a file</summary>
>
> - Wrote `./tb/controller_tb.sv` (+296 -0)
>
> </details>
>
> Controller bench is written. I’m running `make controller`; if the phase expectations are off by even one edge, this should make it very obvious.
>
> <details><summary>Ran a command</summary>
>
> - Ran `make controller`
>
> </details>
>
> The controller test caught a real reset-output issue: while reset was asserted and `start` was high, `accept` was combinationally high because it only looked at the IDLE state. I’m gating `accept` with `rst_n` so reset cleanly suppresses new transactions.
>
> <details><summary>Edited a file</summary>
>
> - Wrote `./rtl/controller.sv` (+1 -1)
>
> </details>
>
> That fix is in. I’m rerunning the controller target now, including the lower stages, to verify the reset behavior and the rest of the transaction timing together.
>
> <details><summary>Ran a command</summary>
>
> - Ran `make controller`
>
> </details>
>
> Controller is now passing with 68 checks after the reset gating fix. I’m adding the top-level bench last: it will verify latched inputs, held outputs before capture, ignored starts while busy, reset abort, consecutive products, random 4x4 products, plus smaller parameterized instances.
>
> <details><summary>Created a file</summary>
>
> - Wrote `./tb/tpu_top_tb.sv` (+496 -0)
>
> </details>
>
> Top-level RTL and bench are in. I’m running `make tpu` now, which will compile every dependency and then exercise the full transaction path.
>
> <details><summary>Ran a command</summary>
>
> - Ran `make tpu`
>
> </details>
>
> `make tpu` passed through all five stages, including 1,729 top-level checks. I’m doing the required final `make test` regression now as fresh verification evidence.
>
> <details><summary>Ran a command</summary>
>
> - Ran `make test`
>
> </details>
>
> The full regression passed. I’m doing one last quick audit of the generated source list and compile logs for warnings so the final report is grounded in the artifacts, not just the terminal summary.
>
> <details><summary>Explored a list, ran 2 commands</summary>
>
> <details><summary>Explored a list</summary>
>
> - Listed files in `rtl`
>
> </details>
>
> - Ran `rg -n "warning|error|sorry" sim/*_compile.log sim/*_run.log`
>
> - Ran `rg -n "TEST RESULT|Tests:|Errors:|SIMULATION RESULT" sim/*_run.log`
>
> </details>
</details>

Built the TPU project end to end and verified it with Icarus.

Implemented:
- RTL: [mac.sv](./rtl/mac.sv), [pe.sv](./rtl/pe.sv), [systolic_array.sv](./rtl/systolic_array.sv), [controller.sv](./rtl/controller.sv), [tpu_top.sv](./rtl/tpu_top.sv)
- Self-checking benches under `tb/` for all five stages

Final command run:

```sh
make test
```

Result: exit status `0`, full regression passed.

Summaries from fresh run:
- `MAC TEST RESULT: PASS` — Tests: `228`, Errors: `0`
- `PE TEST RESULT: PASS` — Tests: `178`, Errors: `0`
- `SYSTOLIC_ARRAY TEST RESULT: PASS` — Tests: `853`, Errors: `0`
- `CONTROLLER TEST RESULT: PASS` — Tests: `68`, Errors: `0`
- `TPU_TOP TEST RESULT: PASS` — Tests: `1729`, Errors: `0`

No compiler warnings/errors were found in the compile/run logs. Coverage includes signed extrema, fixed-seed randomized matrix products, `ARRAY_SIZE` 1/2/4 cases, non-default data widths, reset/clear/hold behavior, busy-start rejection, input latching, and consecutive transactions. This is simulation verification only, not synthesis or hardware signoff.
