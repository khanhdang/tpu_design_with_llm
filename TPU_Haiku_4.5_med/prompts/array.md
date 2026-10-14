Task: implement Systolic array FROM SCRATCH, then verify it.
Stage files: rtl/systolic_array.sv and tb/systolic_array_tb.sv.
Final summary module name: SYSTOLIC_ARRAY.
Required verification command: make array.

Read AGENTS.md, docs/architecture.md, and Makefile before writing files.
Use file-editing and shell tools to do the work; code or commands in your reply
are not an implementation or an executed test.

This is a fresh implementation of the requested stage. Treat its existing RTL,
testbench, and old simulation logs as unverified. Derive the new code from the
architecture, not from the old stage code. Replace whole files; do not append
another module or always block to an existing file.

Before replacing the named stage files, move any existing .sv or .v versions
to a unique directory under sim/restart-backup/, preserving rtl/ and tb/ paths
inside that backup. Keep unrelated files and lower-stage sources intact.
Create only the named .sv RTL and testbench for this stage. Use previously
verified lower modules through their specified interfaces.

Do not change AGENTS.md, docs/architecture.md, Makefile, or the simulation
scripts to obtain PASS. Do not create higher-stage modules.

The testbench must:
- Generate clock and synchronous active-low reset. Drive inputs on the falling
  edge; sample outputs after rising-edge nonblocking updates settle.
- Calculate expected values independently from the DUT. Update the reference
  for every operation; do not leave expected values permanently at zero.
- Increment tests for each comparison and errors for each mismatch. Use !==.
  A mismatch prints inputs/control state and expected/actual outputs.
- Include a bounded watchdog. On timeout, increment errors and finish as FAIL.
- Print exactly one final summary after all stimuli and comparisons finish.
  Select PASS only when errors==0 and tests>0; otherwise select FAIL.
  Print the actual counters with %0d:
    <MODULE> TEST RESULT: PASS or FAIL
    Tests: <actual tests>
    Errors: <actual errors>
  End with $finish. Never hardcode PASS or Errors: 0.

Run the requested make target using the shell tool. Read its exit status,
compiler warnings, and simulation output. Fix compilation/test failures and
rerun that same target until it passes. Never replace test expectations with
DUT outputs or remove failing cases to force success. If tools are unavailable,
report NOT VERIFIED and stop; do not invent command output.

Stop after the requested stage. Report files changed, the command actually run,
its exit status, the final summary copied from the new simulation output, and
remaining warnings/limitations. Do not infer PASS from file creation.

First execute make pe with the shell tool. If it fails, STOP and
report the failure; return to the preceding stage. Do not rewrite or bypass
lower modules to proceed. After it passes, continue with this stage.

Use the packed ports a_left[N*DATA_WIDTH-1:0], b_top[N*DATA_WIDTH-1:0],
and c[N*N*ACC_WIDTH-1:0] from the architecture. Do not replace these with
unpacked array ports. Instantiate N*N PEs with nested generate loops and
ordinary wires/port connections. Never assign a child's input or accumulator
through a hierarchical procedural assignment.

For PE(i,j), A comes from a_left lane i if j=0, else PE(i,j-1).a_out.
B comes from b_top lane j if i=0, else PE(i-1,j).b_out.
Map every PE accumulator to c[(i*N+j)*ACC_WIDTH +: ACC_WIDTH].
Connect common clock, reset, clr, and en to every PE.

In the TB, calculate C[i][j]=sum_k(A[i][k]*B[k][j]) with independent signed
nested loops. Clear the array before each matrix. Drive the architecture's
skewed lanes for t=0 through 3*N-3: A[i][t-i] and B[t-j][j], zero outside range.
Advance t only on enabled compute edges. Compare ALL N*N output slices after
the last compute update settles. Test zero, true identity (diagonal 1), positive,
negative, mixed-sign, extrema, and at least 20 fixed-seed random matrix pairs.
Test a mid-stream enable stall and clear/reset of forwarding and accumulation.
Actually instantiate N=1 and N=2 test cases alongside default N=4; changing
input values on a fixed N=4 DUT does not test parameterization.
Aggregate all instances into one SYSTOLIC_ARRAY summary. Run make array.
Stop; do not implement the controller.
