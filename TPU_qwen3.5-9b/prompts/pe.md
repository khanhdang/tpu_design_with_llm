Task: implement PE FROM SCRATCH, then verify it.
Stage files: rtl/pe.sv and tb/pe_tb.sv.
Final summary module name: PE.
Required verification command: make pe.

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

First execute make mac with the shell tool. If it fails, STOP and
report the failure; return to the preceding stage. Do not rewrite or bypass
lower modules to proceed. After it passes, continue with this stage.

Declare parameters in module pe #( ... ), followed by the port list.
Instantiate the verified MAC with a=a_in and b=b_in directly. Do not put
extra input registers before its product. Connect acc to the MAC's output
without adding another driver.
Register a_out<=a_in and b_out<=b_in on each enabled rising edge. Reset/clr zero
both forwarding outputs; otherwise hold when en=0. Use synchronous reset.

Verify the forwarding and accumulation from the SAME sampled input pair:
after one enabled edge with a_in=3 and b_in=-4, forwarding is 3 and -4 and
the cleared accumulator is -12. Change operands every enabled cycle to expose
extra pipeline stages. Test sign extrema, multiple products, hold, clr priority,
and reset. Use a reference accumulator plus reference forwarding registers
updated from TB-driven inputs, not DUT signals. Include fixed-seed random
cycles and a non-default DATA_WIDTH instance. Aggregate checks/errors into one
PE summary. Run make pe. Stop; do not implement the array.
