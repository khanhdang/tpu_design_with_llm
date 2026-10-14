// Self-checking testbench for tpu_top.
// Four harness instances: N=4 default, N=2 default, N=1 default, and N=2 with
// DATA_WIDTH=4 / ACC_WIDTH=16. Each harness has its own DUT, its own TB-side
// matrices, and an independent reference for the result (signed loops with
// sufficiently wide intermediates) and for the transaction timing.
// Timing reference: after accept, busy is high for 3*N cycles (CLEAR, 3*N-2
// RUN, CAPTURE), then done is high for exactly one cycle. c_matrix keeps the
// previous result until the capture edge and holds the new one from done on.

// One TPU instance plus stimulus, reference, and checker.
module tpu_harness #(
    parameter int N    = 4,
    parameter int DW   = 8,
    parameter int AW   = 32,
    parameter int SEED = 1
) (
    input  logic   clk,
    output integer tests,
    output integer errors,
    output logic   finished
);
    localparam longint VMAX = (longint'(1) << (DW - 1)) - 1;
    localparam longint VMIN = -(longint'(1) << (DW - 1));
    localparam int     TXN_CYCLES = 3 * N;     // busy cycles per transaction
    localparam int     TIMEOUT    = 3 * N + 10;

    logic                       rst_n = 1'b0;
    logic                       start = 1'b0;
    logic [N*N*DW-1:0]          a_matrix = '0;
    logic [N*N*DW-1:0]          b_matrix = '0;
    logic [N*N*AW-1:0]          c_matrix;
    logic                       busy;
    logic                       done;

    tpu_top #(
        .DATA_WIDTH(DW),
        .ACC_WIDTH (AW),
        .ARRAY_SIZE(N)
    ) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .a_matrix(a_matrix), .b_matrix(b_matrix),
        .c_matrix(c_matrix), .busy(busy), .done(done)
    );

    integer seed = SEED;
    integer txn_idx = 0;        // index of the current matrix pair (for reports)
    integer done_seen = 0;      // DUT done cycles observed
    integer txns_started = 0;   // reference accepted transactions
    integer txns_completed = 0; // reference completed transactions
    bit     aborted = 1'b0;

    // Matrices for the current request, and the result they must produce.
    longint A [0:N-1][0:N-1];
    longint B [0:N-1][0:N-1];
    longint pending [0:N-1][0:N-1];

    // Reference state. tq = -1 idle; 0..TXN_CYCLES-1 busy; TXN_CYCLES done cycle.
    integer tq = -1;
    longint txn_c [0:N-1][0:N-1];
    longint pub   [0:N-1][0:N-1];

    // Truncate to a DW-bit or AW-bit pattern.
    function automatic logic [DW-1:0] trd(input longint v);
        trd = v[DW-1:0];
    endfunction

    function automatic logic [AW-1:0] tra(input longint v);
        tra = v[AW-1:0];
    endfunction

    // Wrap x to a signed w-bit value.
    function automatic longint wrap(input longint x, input int w);
        longint m;
        longint r;
        begin
            m = longint'(1) << w;
            r = x % m;
            if (r < 0)
                r = r + m;
            if (r >= (m >> 1))
                r = r - m;
            wrap = r;
        end
    endfunction

    // Uniform integer in [0, m) from the fixed seed.
    function automatic longint rnd_u(input longint m);
        rnd_u = longint'($unsigned($random(seed))) % m;
    endfunction

    // Fill A (which=0) or B (which=1) with one value class (see tpu_top_tb modes).
    task automatic fill(input int which, input int mode);
        integer r;
        integer k;
        longint v;
        begin
            for (r = 0; r < N; r++)
                for (k = 0; k < N; k++) begin
                    case (mode)
                        0: v = 0;                                   // zero
                        1: v = 1 + rnd_u(VMAX);                     // positive
                        2: v = -1 - rnd_u(-VMIN);                   // negative
                        3: v = VMIN + rnd_u(VMAX - VMIN + 1);       // mixed sign
                        4: v = ((r + k) % 2 == 0) ? VMIN : VMAX;    // extrema checker
                        5: v = VMIN;                                // all minimum
                        6: v = VMAX;                                // all maximum
                        default: v = 0;
                    endcase
                    if (which == 0)
                        A[r][k] = v;
                    else
                        B[r][k] = v;
                end
        end
    endtask

    task automatic set_identity(input int which);
        integer r;
        integer k;
        longint v;
        begin
            for (r = 0; r < N; r++)
                for (k = 0; k < N; k++) begin
                    v = (r == k) ? 1 : 0;
                    if (which == 0)
                        A[r][k] = v;
                    else
                        B[r][k] = v;
                end
        end
    endtask

    // Independent reference: pending = A x B with signed loops, wrapped to AW.
    task automatic compute_pending();
        integer i;
        integer j;
        integer k;
        longint s;
        begin
            for (i = 0; i < N; i++)
                for (j = 0; j < N; j++) begin
                    s = 0;
                    for (k = 0; k < N; k++)
                        s = s + A[i][k] * B[k][j];
                    pending[i][j] = wrap(s, AW);
                end
        end
    endtask

    // Report one mismatch with the matrix index, seed, and control state.
    task automatic report(input string what, input int r, input int col,
                          input string exp_s, input string got_s);
        begin
            $display("FAIL TPU N=%0d DW=%0d seed=%0d txn=%0d %s[%0d][%0d]: expected=%s got=%s (tq=%0d rst_n=%0b start=%0b busy=%0b done=%0b)",
                     N, DW, SEED, txn_idx, what, r, col, exp_s, got_s, tq, rst_n, start, busy, done);
        end
    endtask

    // Compare busy, done, and every c slice with the reference for this cycle.
    task automatic check_expect();
        logic exp_busy;
        logic exp_done;
        integer r;
        integer col;
        logic [AW-1:0] exp_bits;
        begin
            exp_busy = (tq >= 0) && (tq < TXN_CYCLES);
            exp_done = (tq == TXN_CYCLES);
            tests++;
            if (busy !== exp_busy) begin
                errors++;
                $display("FAIL TPU N=%0d DW=%0d seed=%0d txn=%0d busy: expected=%0b got=%0b (tq=%0d)",
                         N, DW, SEED, txn_idx, exp_busy, busy, tq);
            end
            tests++;
            if (done !== exp_done) begin
                errors++;
                $display("FAIL TPU N=%0d DW=%0d seed=%0d txn=%0d done: expected=%0b got=%0b (tq=%0d)",
                         N, DW, SEED, txn_idx, exp_done, done, tq);
            end
            if (done === 1'b1)
                done_seen++;
            for (r = 0; r < N; r++)
                for (col = 0; col < N; col++) begin
                    exp_bits = tra(pub[r][col]);
                    tests++;
                    if (c_matrix[(r*N+col)*AW +: AW] !== exp_bits) begin
                        errors++;
                        report("c", r, col,
                               $sformatf("%0d", $signed(exp_bits)),
                               $sformatf("%0d", $signed(c_matrix[(r*N+col)*AW +: AW])));
                    end
                end
        end
    endtask

    // Advance the reference across one rising edge using the driven inputs.
    task automatic update_ref(input logic rstn, input logic st);
        integer r;
        integer col;
        begin
            if (!rstn) begin
                tq = -1;
                for (r = 0; r < N; r++)
                    for (col = 0; col < N; col++)
                        pub[r][col] = 0;
            end else begin
                if (tq == TXN_CYCLES)
                    tq = -1;                      // done cycle ends
                if (tq >= 0) begin
                    tq++;
                    if (tq == TXN_CYCLES) begin   // capture edge publishes the result
                        for (r = 0; r < N; r++)
                            for (col = 0; col < N; col++)
                                pub[r][col] = txn_c[r][col];
                        txns_completed++;
                    end
                end else if (st) begin            // accepted request latches pending
                    tq = 0;
                    for (r = 0; r < N; r++)
                        for (col = 0; col < N; col++)
                            txn_c[r][col] = pending[r][col];
                    txns_started++;
                end
            end
        end
    endtask

    // Pack the TB matrices (use_mat=1) or random junk (use_mat=0) onto the buses.
    task automatic drive_buses(input logic use_mat);
        integer r;
        integer col;
        begin
            for (r = 0; r < N; r++)
                for (col = 0; col < N; col++) begin
                    if (use_mat) begin
                        a_matrix[(r*N+col)*DW +: DW] = trd(A[r][col]);
                        b_matrix[(r*N+col)*DW +: DW] = trd(B[r][col]);
                    end else begin
                        a_matrix[(r*N+col)*DW +: DW] = trd($random(seed));
                        b_matrix[(r*N+col)*DW +: DW] = trd($random(seed));
                    end
                end
        end
    endtask

    // One clock cycle: drive at negedge, check after settling, advance the reference.
    // start is driven as given, so requests during busy or reset are presented too.
    task automatic tick(input logic rstn, input logic st, input logic use_mat);
        begin
            @(negedge clk);
            rst_n = rstn;
            start = st;
            drive_buses(use_mat);
            #1;
            if (rstn)
                check_expect();
            @(posedge clk);
            update_ref(rstn, st);
            #1;
            if (!rstn)
                check_expect();
        end
    endtask

    // Accept the current A/B, run to completion with junk on the buses and
    // random requests while busy, and check every cycle.
    task automatic run_pair(input string tag);
        integer k;
        begin
            if (!aborted) begin
                compute_pending();
                tick(1'b1, 1'b1, 1'b1);            // accept edge (matrices latched)
                for (k = 0; k < TIMEOUT && tq >= 0; k++)
                    tick(1'b1, (tq < TXN_CYCLES) ? $unsigned($random(seed)) % 2 : 1'b0, 1'b0);
                if (tq >= 0) begin
                    errors++;
                    $display("FAIL TPU N=%0d DW=%0d seed=%0d txn=%0d timeout: %s did not finish in %0d cycles",
                             N, DW, SEED, txn_idx, tag, TIMEOUT);
                    aborted = 1'b1;
                end
            end
            txn_idx++;
        end
    endtask

    // Back-to-back: the second request is presented on the done cycle and accepted there.
    task automatic back_to_back(input string tag);
        integer k;
        begin
            if (!aborted) begin
                compute_pending();
                tick(1'b1, 1'b1, 1'b1);
                for (k = 0; k < TIMEOUT && tq >= 0 && tq < TXN_CYCLES; k++)
                    tick(1'b1, $unsigned($random(seed)) % 2, 1'b0);
                txn_idx++;
                // Next pair is driven on the done cycle, so it is accepted immediately.
                fill(0, 3);
                fill(1, 3);
                compute_pending();
                tick(1'b1, 1'b1, 1'b1);
                for (k = 0; k < TIMEOUT && tq >= 0; k++)
                    tick(1'b1, (tq < TXN_CYCLES) ? $unsigned($random(seed)) % 2 : 1'b0, 1'b0);
                if (tq >= 0) begin
                    errors++;
                    $display("FAIL TPU N=%0d DW=%0d seed=%0d txn=%0d timeout: %s did not finish",
                             N, DW, SEED, txn_idx, tag);
                    aborted = 1'b1;
                end
                txn_idx++;
            end
        end
    endtask

    // Reset in the middle of a transaction: outputs must zero and the next run must work.
    task automatic reset_mid_transaction(input string tag);
        integer k;
        begin
            if (!aborted) begin
                compute_pending();
                tick(1'b1, 1'b1, 1'b1);
                for (k = 0; k < 2; k++)
                    tick(1'b1, 1'b1, 1'b0);     // busy requests ignored
                tick(1'b0, 1'b1, 1'b0);        // reset with start high
                tick(1'b1, 1'b0, 1'b0);
                tick(1'b1, 1'b0, 1'b0);
                if (busy !== 1'b0 || done !== 1'b0) begin
                    errors++;
                    $display("FAIL TPU N=%0d DW=%0d seed=%0d %s: busy/done not idle after reset",
                             N, DW, SEED, tag);
                end
            end
            txn_idx++;
        end
    endtask

    // Build the value-class and random pairs for this instance.
    task automatic structured_pairs();
        begin
            fill(0, 0); fill(1, 0); run_pair("zero x zero");
            set_identity(0); fill(1, 3); run_pair("identity x mixed");
            fill(0, 3); set_identity(1); run_pair("mixed x identity");
            set_identity(0); set_identity(1); run_pair("identity x identity");
            fill(0, 1); fill(1, 1); run_pair("positive x positive");
            fill(0, 2); fill(1, 2); run_pair("negative x negative");
            fill(0, 3); fill(1, 3); run_pair("mixed x mixed");
            fill(0, 4); fill(1, 4); run_pair("extrema checker");
            fill(0, 5); fill(1, 6); run_pair("all min x all max");
            fill(0, 6); fill(1, 6); run_pair("all max x all max");
            fill(0, 5); fill(1, 5); run_pair("all min x all min");
        end
    endtask

    initial begin
        integer p;
        finished = 1'b0;
        tests    = 0;
        errors   = 0;

        // Reset: outputs zero after reset, then idle.
        tick(1'b0, 1'b0, 1'b0);
        tick(1'b0, 1'b0, 1'b0);
        tick(1'b1, 1'b0, 1'b0);
        tick(1'b1, 1'b0, 1'b0);

        structured_pairs();

        // Back-to-back requests, then reset mid-transaction and recovery.
        fill(0, 3); fill(1, 3);
        back_to_back("back-to-back");
        fill(0, 1); fill(1, 1);
        reset_mid_transaction("reset mid-transaction");
        fill(0, 3); fill(1, 3);
        run_pair("after reset");

        // Fixed-seed random pairs with full-range values.
        for (p = 0; p < 50; p++) begin
            fill(0, 3);
            fill(1, 3);
            run_pair("random pair");
        end

        // Done pulses must match completed transactions.
        tick(1'b1, 1'b0, 1'b0);
        tests++;
        if (done_seen !== txns_completed) begin
            errors++;
            $display("FAIL TPU N=%0d DW=%0d seed=%0d done pulses: expected=%0d seen=%0d",
                     N, DW, SEED, txns_completed, done_seen);
        end

        finished = 1'b1;
    end
endmodule

module tpu_top_tb;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    integer t_a, e_a, t_b, e_b, t_c, e_c, t_d, e_d;
    logic   f_a, f_b, f_c, f_d;

    tpu_harness #(.N(4), .DW(8), .AW(32), .SEED(101)) h_a (
        .clk(clk), .tests(t_a), .errors(e_a), .finished(f_a));
    tpu_harness #(.N(2), .DW(8), .AW(32), .SEED(202)) h_b (
        .clk(clk), .tests(t_b), .errors(e_b), .finished(f_b));
    tpu_harness #(.N(1), .DW(8), .AW(32), .SEED(303)) h_c (
        .clk(clk), .tests(t_c), .errors(e_c), .finished(f_c));
    tpu_harness #(.N(2), .DW(4), .AW(16), .SEED(404)) h_d (
        .clk(clk), .tests(t_d), .errors(e_d), .finished(f_d));

    integer tests;
    integer errors;
    bit     finished = 1'b0;

    task automatic print_summary;
        begin
            tests  = t_a + t_b + t_c + t_d;
            errors = e_a + e_b + e_c + e_d;
            if (errors == 0 && tests > 0)
                $display("TPU_TOP TEST RESULT: PASS");
            else
                $display("TPU_TOP TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
        end
    endtask

    // Watchdog: bounded run time; reports FAIL if the harnesses never finish.
    initial begin
        #5000000;
        if (!finished) begin
            finished = 1'b1;
            $display("FAIL TPU_TOP watchdog timeout");
            tests  = t_a + t_b + t_c + t_d;
            errors = e_a + e_b + e_c + e_d + 1;
            $display("TPU_TOP TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
            $finish;
        end
    end

    initial begin
        $dumpfile("sim/tpu_top_tb.vcd");
        $dumpvars(0, tpu_top_tb);
        wait (f_a && f_b && f_c && f_d);
        #1;
        finished = 1'b1;
        print_summary();
        $finish;
    end
endmodule
