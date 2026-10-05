# TPU Architecture

## Objective

Implement a small systolic-array matrix multiplication accelerator.

## Parameters

| Parameter | Default | Meaning |
| --- | --- | --- |
| DATA_WIDTH | 8 | Signed input element width |
| ACC_WIDTH | 32 | Signed accumulator/output element width |
| ARRAY_SIZE | 4 | Square matrix and systolic array dimension |

Let N = ARRAY_SIZE. Compute one N × N matrix product per transaction.
Support N >= 1 and ACC_WIDTH >= 2 * DATA_WIDTH.

## Arithmetic

Signed INT8 multiplication and signed INT32 accumulation at the defaults.
Explicitly sign-extend the 2 * DATA_WIDTH product before accumulation.
Arithmetic wraps to ACC_WIDTH bits on overflow; there is no saturation.

C = A × B

## Architecture

4 × 4 systolic array.

Each PE contains:

- INT8 A register
- INT8 B register
- multiplier
- INT32 accumulator

A propagates from left to right.
B propagates from top to bottom.

## Implementation contract

The following choices complete the previously unspecified interfaces and timing.
They preserve the signed 4 × 4 systolic architecture above. Use them consistently
across modules and testbenches; update this document before changing a contract.

All sequential modules sample on the rising edge of clk. rst_n is synchronous,
active low. Reset takes priority over all other controls. Use nonblocking
assignments for sequential logic. No DSP, AXI, external memory, or host driver
is required for this simulation project.

Use .sv for new RTL and testbenches. The simulation runner also accepts .v,
but never both extensions for the same module.

| Module | File | Parameters | Ports and behavior |
| --- | --- | --- | --- |
| mac | rtl/mac.sv | DATA_WIDTH, ACC_WIDTH | clk, rst_n, clr, en, signed a/b inputs, signed acc output. clr zeros acc; otherwise en accumulates a*b; otherwise hold. |
| pe | rtl/pe.sv | DATA_WIDTH, ACC_WIDTH | clk, rst_n, clr, en, signed a_in/b_in, signed a_out/b_out, signed acc. Instantiate mac using a_in/b_in directly. When en, forward those inputs through one register each. Reset/clr zero forwarding registers and acc; otherwise hold when disabled. |
| systolic_array | rtl/systolic_array.sv | DATA_WIDTH, ACC_WIDTH, ARRAY_SIZE | clk, rst_n, clr, en, packed a_left/b_top input lanes, packed c output. Instantiate N*N PEs. Feed A rightward and B downward; expose all accumulators in row-major order. |
| controller | rtl/controller.sv | ARRAY_SIZE | clk, rst_n, start; accept, clear, compute, capture, busy, done outputs; step output. Generate transaction timing described below. Guard counter widths with max(1, $clog2(...)). |
| tpu_top | rtl/tpu_top.sv | DATA_WIDTH, ACC_WIDTH, ARRAY_SIZE | clk, rst_n, start, packed a_matrix/b_matrix inputs, packed c_matrix output, busy, done. Latch inputs on accept; feed skewed lanes to the array; latch results on capture. |

MAC accumulation must use the inputs sampled at the current edge. Do not insert
another input register before the MAC product: that changes the array timing.
For MAC, PE, and array, clr overrides en and clears the entire compute state.
All PEs advance together when en is asserted. Zero padding handles empty lanes;
per-lane valid signals are unnecessary for this fixed square transaction.

## Packed matrix interface

a_matrix and b_matrix each have N*N*DATA_WIDTH bits. c_matrix has
N*N*ACC_WIDTH bits. Element (row, col) occupies:

    a_matrix[(row*N + col)*DATA_WIDTH +: DATA_WIDTH]
    b_matrix[(row*N + col)*DATA_WIDTH +: DATA_WIDTH]
    c_matrix[(row*N + col)*ACC_WIDTH +: ACC_WIDTH]

Element (0, 0) is in the least-significant slice. Packed buses themselves need
not be signed; cast each element slice with $signed before arithmetic.
a_left and b_top each have N*DATA_WIDTH bits; lane i occupies
bits [i*DATA_WIDTH +: DATA_WIDTH]. The array c bus uses the same result packing.

## Transaction timing

1. In IDLE, accept = start && !busy. On that edge, top latches both matrices.
2. Enter CLEAR: busy=1, clear=1, compute=0. Clear all PE registers and accumulators
   on the next edge, without clearing the previously published c_matrix.
3. Enter RUN: busy=1, compute=1. step runs from 0 through 3*N-3 inclusive,
   giving 3*N-2 compute edges. step is meaningful only while compute=1.
4. Enter CAPTURE: busy=1, capture=1, compute=0. On the next edge, top latches
   all final array accumulators. The controller returns to IDLE and pulses
   registered done for one cycle, so c_matrix is valid when done is observed.
5. Hold c_matrix until the next completed transaction. Reset zeros c_matrix,
   busy, and done, and aborts any in-flight transaction.

The controller outputs accept/clear/compute/capture describe actions for the
upcoming rising edge. done is a registered completion pulse. clear, compute,
and capture must never overlap. start is a one-cycle request; requests while
busy are ignored. A new request can be accepted on the first idle edge after
completion. Holding start high can start another transaction when idle.

During RUN step t, top drives:

    a_left lane i = A[i][t-i] if 0 <= t-i < N, else 0
    b_top  lane j = B[t-j][j] if 0 <= t-j < N, else 0

With one register per hop, A[i][k] and B[k][j] meet at PE(i,j) on step k+i+j.
The last product reaches PE(N-1,N-1) at step 3*N-3. The separate capture edge
allows the last nonblocking accumulator updates to settle before publishing C.

## Files and build order

| Stage | Testbench | Command |
| --- | --- | --- |
| MAC | tb/mac_tb.sv | make mac |
| PE | tb/pe_tb.sv | make pe |
| Systolic array | tb/systolic_array_tb.sv | make array |
| Controller | tb/controller_tb.sv | make controller |
| TPU top | tb/tpu_top_tb.sv | make tpu |

Each command reruns all lower stages first and stops on the first failure.
make test / make regression runs every stage; a missing stage is a failure.

## Verification

Use Icarus Verilog.

Test:
1. all-zero matrices
2. identity matrix
3. positive values
4. negative values
5. random matrices

Also cover signed extrema (-128 and 127 at DATA_WIDTH=8), mixed signs,
MAC enable/clear priority, PE propagation, array skew timing, controller timeout,
ignored start while busy, reset during a transaction, and consecutive transactions.
Exercise non-default ARRAY_SIZE values (including 1) and data widths before
declaring parameterization verified. Keep randomized tests reproducible with
a fixed seed and report that seed on failure.

The testbench must calculate expected matrix multiplication independently using
software-style nested loops, explicitly signed elements and sufficiently wide
intermediates. Compare every result with case inequality (!==), so X/Z cannot
pass. Include a cycle-based watchdog. Drive stimuli away from the sampling edge
and check results after nonblocking updates have settled.

Every testbench must generate clock/reset, count checks and errors, emit useful
failure details, and finish with $finish. Print exactly one final summary in
the format below; MODULE is MAC, PE, SYSTOLIC_ARRAY, CONTROLLER, or TPU_TOP:

    MODULE TEST RESULT: PASS
    Tests: 100
    Errors: 0

Use FAIL instead of PASS whenever errors > 0. Tests must be positive. The runner
requires this summary even when vvp exits successfully, because $finish alone
does not signal a failed comparison to make. Waveforms, when enabled, go to
sim/<module>_tb.vcd. Compiler and runtime logs also go to sim/.
