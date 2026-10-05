Task: implement Controller FROM SCRATCH, then verify it.
Stage files: rtl/controller.sv and tb/controller_tb.sv.
Final summary module name: CONTROLLER.
Required verification command: make controller.

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

First execute make array with the shell tool. If it fails, STOP and
report the failure; return to the preceding stage. Do not rewrite or bypass
lower modules to proceed. After it passes, continue with this stage.

Use four states IDLE, CLEAR, RUN, CAPTURE, with an explicitly adequate enum
width (for example logic [1:0]). Use $clog2, not undefined log2/clog2 functions.
Guard step width for N=1: max(1, $clog2(3*N-2)).
Decode accept/clear/compute/capture/busy from the state for the UPCOMING edge.
accept is start when idle; busy is true outside idle.
Register done as a one-cycle pulse when leaving CAPTURE.

On accept: enter CLEAR. On the clear edge: enter RUN with step=0.
In RUN: compute on exactly 3*N-2 edges, with step 0 through 3*N-3.
After the final compute edge enter CAPTURE. On the capture edge return to IDLE
and assert done for one cycle. Default inactive controls each cycle through
state decoding; do not leave clear/compute/capture stuck high.
Use synchronous active-low reset to return to IDLE, step=0, done=0.

The TB checks controller behavior, not matrix outputs. DUT outputs are wires;
do not drive them from the testbench. Check every phase and step, busy, accepted
idle requests, ignored busy requests, separate clear/run/capture, done pulse
width, idle after completion, reset during RUN, and consecutive transactions.
Instantiate N=1, N=2, and N=4; compare compute-edge counts to 1, 4, and 10.
Use an independently sequenced state/timing reference and a cycle timeout.
Aggregate all instances into one CONTROLLER summary. Run make controller.
Stop; do not implement TPU top.
