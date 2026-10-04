# Build TPU project

> check this folder and build

<details><summary>16 previous messages</summary>

> I’ll inspect the project instructions and current tree first, then run the prescribed staged Icarus build in order. If a stage fails, I’ll trace the failure and make only the focused RTL/testbench fixes needed.
>
> <details><summary>Ran 2 commands</summary>
>
> - Ran `pwd && rg --files -g 'AGENTS.md' -g 'README.md' -g 'Makefile' -g 'docs/architecture.md' -g 'rtl/**' -g 'tb/**' -g 'prompts.md' | sort`
> - Ran `sed -n '1,260p' docs/architecture.md && sed -n '1,240p' README.md && sed -n '1,280p' Makefile && sed -n '1,240p' prompts.md && find prompts -maxdepth 2 -type f -print 2>/dev/null | sort`
>
> </details>
>
> The workspace is a deliberate empty scaffold: both `rtl/` and `tb/` contain only placeholders, so this is a full five-stage implementation rather than a conventional compile. I’ve confirmed the architecture contract; next I’m checking the runner’s exact acceptance rules and tool availability, then I’ll implement and verify MAC → PE → array → controller → top.
>
> <details><summary>Ran a command</summary>
>
> - Ran `git status --short && sed -n '1,260p' scripts/simulate.py && for f in prompts/mac.md prompts/pe.md prompts/array.md prompts/controller.md prompts/tpu.md prompts/regression.md; do echo "===== $f ====="; sed -n '1,220p' "$f"; done && make doctor`
>
> </details>
>
> The toolchain is ready (`iverilog` and `vvp` are installed). Git status is noisy because the parent repository has corrupt macOS `._` pack-index artifacts, but this project directory itself is an untracked scaffold; I’ll avoid touching the parent or `.git` and work only in this folder. I’m starting with the MAC and its self-checking parameter/wraparound coverage.
>
> <details><summary>Created 2 files, ran a command</summary>
>
> - Wrote `./rtl/mac.sv` (+30 -0)
> - Wrote `./tb/mac_tb.sv` (+148 -0)
> - Ran `make mac`
>
> </details>
>
> MAC passes 121 checks with zero errors. The only compiler warning is a missing RTL time unit, so I’m cleaning that up before advancing; then I’ll add the PE with same-edge forwarding/accumulation checks and a non-default-width instance.
>
> <details><summary>Created 2 files, edited a file, ran a command</summary>
>
> - Wrote `./rtl/mac.sv` (+2 -0)
> - Wrote `./rtl/pe.sv` (+37 -0)
> - Wrote `./tb/pe_tb.sv` (+176 -0)
> - Ran `make pe`
>
> </details>
>
> PE now passes 408 checks, and the staged rerun confirms MAC remains clean. I’m moving to the array: the testbench will exercise N=4 with directed and 20 reproducible random products, plus real N=2/non-default-width and N=1 instances, including an enable stall and reset/clear behavior.
>
> <details><summary>Created 2 files, ran a command</summary>
>
> - Wrote `./rtl/systolic_array.sv` (+53 -0)
> - Wrote `./tb/systolic_array_tb.sv` (+266 -0)
> - Ran `make array`
>
> </details>
>
> The systolic array passes 834 checks with no compiler warnings; that includes all 16 outputs per N=4 case, 20 seeded random pairs, an actual N=2 4-bit instance, N=1, stalls, clear, and reset. Next is the controller, where I’m validating the exact upcoming-edge phase decode and compute counts of 1, 4, and 10.
>
> <details><summary>Created 2 files, ran a command</summary>
>
> - Wrote `./rtl/controller.sv` (+72 -0)
> - Wrote `./tb/controller_tb.sv` (+203 -0)
> - Ran `make controller`
>
> </details>
>
> Controller passes 146 checks across N=1/2/4, including exact 1/4/10 compute-edge counts, ignored busy requests, reset abort, pulse width, and consecutive transactions. I’m implementing the top-level integration now; its verification will run 56 directed/random N=4 products plus N=1/N=2 configurations, input-latching corruption tests, stable published results, busy-request rejection, reset abort, and back-to-back operation.
>
> <details><summary>Created 2 files, ran a command</summary>
>
> - Wrote `./rtl/tpu_top.sv` (+76 -0)
> - Wrote `./tb/tpu_top_tb.sv` (+277 -0)
> - Ran `make tpu`
>
> </details>
>
> The complete staged `make tpu` build now passes all five modules; top-level verification reports 1,759 checks and zero errors. I’m doing the required fresh `make test` regression now and will audit all compile logs for warnings before handing it back.
>
> <details><summary>Ran 2 commands</summary>
>
> - Ran `make test`
> - Ran `for f in sim/mac_compile.log sim/pe_compile.log sim/systolic_array_compile.log sim/controller_compile.log sim/tpu_top_compile.log; do wc -c "$f"; done
> rg -n -i 'warning|error|fatal' sim/*_compile.log || true
> find rtl tb -maxdepth 1 -type f \( -name '*.sv' -o -name '*.v' \) -print | sort
> for f in sim/*_run.log; do rg 'TEST RESULT|Tests:|Errors:' "$f"; done`
>
> </details>
</details>

Built the complete TPU from the empty scaffold.

Created RTL and self-checking testbenches for:

- [MAC](./rtl/mac.sv)
- [PE](./rtl/pe.sv)
- [Systolic array](./rtl/systolic_array.sv)
- [Controller](./rtl/controller.sv)
- [TPU top](./rtl/tpu_top.sv)

Final `make test` result: exit code 0.

| Stage | Checks | Errors |
|---|---:|---:|
| MAC | 121 | 0 |
| PE | 408 | 0 |
| Systolic array | 834 | 0 |
| Controller | 146 | 0 |
| TPU top | 1,759 | 0 |

All five compiler logs are empty—no warnings or errors. Coverage includes signed extrema, fixed-seed random matrices, N=1/N=2/N=4 configurations, non-default widths, stalls, reset abort, ignored busy requests, and consecutive transactions.

One unrelated repository issue remains: the parent Git object directory contains corrupt macOS `._pack-*.idx` metadata, so `git status` emits errors. This did not affect compilation or simulation. No synthesis or hardware validation was performed.
