Task: implement MAC FROM SCRATCH, then verify it.
Stage files: rtl/mac.sv and tb/mac_tb.sv.
Final summary module name: MAC.
Required verification command: make mac.

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

Implement mac with parameters DATA_WIDTH=8 and ACC_WIDTH=32. Declare a, b,
and acc signed. Use always @(posedge clk) with priority reset, then clr, then
en, then hold. rst_n is synchronous; do not add negedge rst_n to the event list.
Compute a signed 2*DATA_WIDTH product and explicitly sign-extend it to ACC_WIDTH.
Accumulate the current inputs once per enabled edge; wrap at ACC_WIDTH bits.

Test reset, zero product, both sign combinations, repeated accumulation,
enable hold, clr with en=0, clr overriding en=1, and reset overriding all controls.
At 8-bit inputs, 8'h80 is -128 and 8'h7f is +127.
Include known checks such as 3*4=12, (-3)*4=-12, (-128)*127=-16256,
and (-128)*(-128)=16384, clearing between independent cases.
Instantiate a second MAC with ACC_WIDTH=16 and check wraparound using repeated
16384 products, including 32768 represented as signed -32768. Add fixed-seed
random operations checked against a signed reference accumulator.
After both instances finish, aggregate their actual checks/errors into the
single MAC summary. Run make mac. Stop; do not implement PE.
