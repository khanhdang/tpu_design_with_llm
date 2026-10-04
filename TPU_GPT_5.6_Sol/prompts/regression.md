Task: verify the complete freshly implemented TPU.

Read AGENTS.md, docs/architecture.md, and Makefile. Use the shell tool to run
make test now. Do not rewrite working stages from scratch in this command.
Do not accept old logs or a previous reply as verification evidence.

Inspect the command's exit status and every compiler/runtime result. Require
actual module summaries for MAC, PE, SYSTOLIC_ARRAY, CONTROLLER, and TPU_TOP,
with Tests > 0 and Errors == 0 in each. Audit that each summary occurs after
all comparisons and uses real counters; hardcoded PASS/Errors: 0 is invalid.
Expected matrix results must come from independent signed nested-loop references,
not from DUT outputs. Check fixed-seed random coverage and real instantiated
N=1/N=2/non-default width cases, not just comments claiming these cases.

If a module or testbench is missing, STOP and name the stage to implement.
For an actual failure, fix the failing stage only, run its make target, and
rerun make test. Keep lower-stage verification first. Do not change the
architecture, runner, make rules, expected values, or remove failing tests to
force PASS. If tools cannot run, report NOT VERIFIED and the reason.

Finish only after the newly executed full regression exits zero with all five
stages passing. Report files changed, command/exit status, actual checks/errors
per stage copied from the logs, compiler warnings, random seeds, tested
parameter configurations, and limitations. A file being present is not proof
that it compiled or passed. Do not claim synthesis or hardware verification.
