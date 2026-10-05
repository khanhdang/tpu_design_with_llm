Task: implement TPU top FROM SCRATCH, then verify it.
Stage files: rtl/tpu_top.sv and tb/tpu_top_tb.sv.
Final summary module name: TPU_TOP.
Required verification command: make tpu, then make test.

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

First execute make controller with the shell tool. If it fails, STOP and
report the failure; return to the preceding stage. Do not rewrite or bypass
lower modules to proceed. After it passes, continue with this stage.

Instantiate the verified controller and systolic array. Match the controller's
guarded step width. Use packed lane buses and a separate packed array result c.
Wire busy/done to controller outputs without another sequential driver.

On accept, latch ALL elements of a_matrix and b_matrix into internal packed
registers. Generate array boundary lanes from these latched matrices, not from
external inputs: lane i gets A[i][step-i]; lane j gets B[step-j][j], with zero
padding and correct row-major slice indexing. Feed only during compute.
Connect controller clear to array clr and compute to array en.
On capture, register the array's c bus into c_matrix. Reset c_matrix to zero;
otherwise preserve published results until another capture. Use synchronous reset.

Create tb/tpu_top_tb.sv explicitly. Independently calculate each expected result
with signed matrix loops and sufficiently wide reference intermediates.
Test default N=4 zero, identity, positive, negative, mixed-sign and extrema
matrices, plus at least 50 fixed-seed random pairs. Compare every output slice.
Also instantiate N=1 and N=2, including a non-default DATA_WIDTH configuration.
Check that input changes after accept cannot affect the transaction, old results
remain stable before capture, busy requests are ignored, reset aborts execution
and zeros outputs, done lasts one cycle, and consecutive transactions work.
Use bounded waits for done and report the seed/matrix indices on mismatches.

After every instance finishes, print one TPU_TOP summary using aggregated actual
counters. Run make tpu, then make test. Both must succeed; every stage must have
its real self-checking summary. Report the actual per-stage results. Stop.
