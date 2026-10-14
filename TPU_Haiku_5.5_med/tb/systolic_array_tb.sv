// Self-checking testbench for systolic_array.
// Four harness instances exercise different parameterizations: default N=4,
// N=2, N=1 (default widths), and N=4 with DATA_WIDTH=4 / ACC_WIDTH=16.
// Each harness has its own DUT and reference model. Expected C is computed
// with independent signed nested loops from the TB-side A and B matrices.
// The top module aggregates every harness into one SYSTOLIC_ARRAY summary.

// One DUT plus its stimulus generator and reference checker.
module sa_harness #(
    parameter int N    = 4,
    parameter int DW   = 8,
    parameter int AW   = 32,
    parameter int SEED = 1
) (
    input  logic   clk,
    output integer tests,
    output integer errors,
    output logic   done
);
    localparam longint VMAX = (longint'(1) << (DW - 1)) - 1;
    localparam longint VMIN = -(longint'(1) << (DW - 1));
    localparam int     LAST = 3 * N - 3;

    logic                   rst_n = 1'b0;
    logic                   clr   = 1'b0;
    logic                   en    = 1'b0;
    logic [N*DW-1:0]        a_left = '0;
    logic [N*DW-1:0]        b_top  = '0;
    logic [N*N*AW-1:0]      c;

    systolic_array #(
        .DATA_WIDTH(DW),
        .ACC_WIDTH (AW),
        .ARRAY_SIZE(N)
    ) dut (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
        .a_left(a_left), .b_top(b_top), .c(c)
    );

    integer seed = SEED;
    longint A [0:N-1][0:N-1];
    longint B [0:N-1][0:N-1];
    longint C [0:N-1][0:N-1];

    // Truncate a value to a DW-bit or AW-bit pattern.
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

    // Fill matrix A (which=0) or B (which=1) with one of several value classes.
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

    // Identity into A (which=0) or B (which=1).
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

    // Independent reference: C[i][j] = sum_k A[i][k]*B[k][j], wrapped to AW.
    task automatic compute_reference();
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
                    C[i][j] = wrap(s, AW);
                end
        end
    endtask

    // Random values on every unused lane so stalled or idle cycles cannot leak in.
    task automatic junk_lanes();
        integer i;
        begin
            for (i = 0; i < N; i++) begin
                a_left[i*DW +: DW] = trd($random(seed));
                b_top[i*DW +: DW]  = trd($random(seed));
            end
        end
    endtask

    // Skewed lanes for step t: A[i][t-i] and B[t-j][j], zero outside range.
    task automatic drive_lanes(input int t);
        integer i;
        integer k;
        longint av;
        longint bv;
        begin
            for (i = 0; i < N; i++) begin
                k  = t - i;
                av = (k >= 0 && k < N) ? A[i][k] : 0;
                a_left[i*DW +: DW] = trd(av);
            end
            for (i = 0; i < N; i++) begin
                k  = t - i;
                bv = (k >= 0 && k < N) ? B[k][i] : 0;
                b_top[i*DW +: DW] = trd(bv);
            end
        end
    endtask

    // Print the element-level inputs and control state for a failing check.
    task automatic report_mismatch(input int r, input int col, input string tag,
                                   input longint exp_v, input logic [AW-1:0] got);
        begin
            $display("FAIL SA N=%0d DW=%0d C[%0d][%0d] %s: expected=%0d got=%0d (rst_n=%0b clr=%0b en=%0b)",
                     N, DW, r, col, tag, exp_v, $signed(got), rst_n, clr, en);
        end
    endtask

    // Compare all N*N output slices against the reference.
    task automatic check_all(input string tag);
        integer r;
        integer col;
        logic [AW-1:0] exp_bits;
        begin
            for (r = 0; r < N; r++)
                for (col = 0; col < N; col++) begin
                    exp_bits = tra(C[r][col]);
                    tests++;
                    if (c[(r*N+col)*AW +: AW] !== exp_bits) begin
                        errors++;
                        report_mismatch(r, col, tag, C[r][col], c[(r*N+col)*AW +: AW]);
                    end
                end
        end
    endtask

    // Clear the array for one cycle, stream one matrix pair, and check C.
    // stall_at >= 0 inserts a 3-cycle enable-low stall before that step.
    task automatic run_matrix(input string tag, input int stall_at);
        integer t;
        integer s;
        begin
            @(negedge clk);
            clr = 1'b1;
            en  = 1'b0;
            junk_lanes();
            @(posedge clk);

            compute_reference();

            for (t = 0; t <= LAST; t++) begin
                if (t == stall_at) begin
                    for (s = 0; s < 3; s++) begin
                        @(negedge clk);
                        clr = 1'b0;
                        en  = 1'b0;
                        junk_lanes();
                        @(posedge clk);
                    end
                end
                @(negedge clk);
                clr = 1'b0;
                en  = 1'b1;
                drive_lanes(t);
                @(posedge clk);
            end

            // One idle enabled-low edge so the final update has settled before checking.
            @(negedge clk);
            clr = 1'b0;
            en  = 1'b0;
            junk_lanes();
            @(posedge clk);
            #1;
            check_all(tag);
        end
    endtask

    // Load A and B from the mode selectors and run one matrix pair.
    // Mode 7 selects the identity; modes 0-6 select a value class (see fill).
    task automatic run_pair(input string tag, input int mode_a, input int mode_b,
                            input int stall_at);
        begin
            if (mode_a == 7)
                set_identity(0);
            else
                fill(0, mode_a);
            if (mode_b == 7)
                set_identity(1);
            else
                fill(1, mode_b);
            run_matrix(tag, stall_at);
        end
    endtask

    // Partial stream, then reset; every accumulator must read zero afterwards.
    task automatic reset_mid_stream();
        integer t;
        begin
            fill(0, 3);
            fill(1, 3);
            @(negedge clk);
            clr = 1'b1;
            en  = 1'b0;
            @(posedge clk);
            for (t = 0; t <= 1 && t <= LAST; t++) begin
                @(negedge clk);
                clr = 1'b0;
                en  = 1'b1;
                drive_lanes(t);
                @(posedge clk);
            end
            @(negedge clk);
            rst_n = 1'b0;
            clr   = 1'b0;
            en    = 1'b1;
            junk_lanes();
            @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            en    = 1'b0;
            @(posedge clk);
            #1;
            set_zero_reference();
            check_all("after reset mid-stream");
        end
    endtask

    // Partial stream, then clear; accumulators must read zero afterwards.
    task automatic clear_mid_stream();
        integer t;
        begin
            fill(0, 3);
            fill(1, 3);
            @(negedge clk);
            clr = 1'b1;
            en  = 1'b0;
            @(posedge clk);
            for (t = 0; t <= 1 && t <= LAST; t++) begin
                @(negedge clk);
                clr = 1'b0;
                en  = 1'b1;
                drive_lanes(t);
                @(posedge clk);
            end
            @(negedge clk);
            clr = 1'b1;
            en  = 1'b1;
            junk_lanes();
            @(posedge clk);
            @(negedge clk);
            clr = 1'b0;
            en  = 1'b0;
            @(posedge clk);
            #1;
            set_zero_reference();
            check_all("after clr mid-stream");
        end
    endtask

    task automatic set_zero_reference();
        integer r;
        integer col;
        begin
            for (r = 0; r < N; r++)
                for (col = 0; col < N; col++)
                    C[r][col] = 0;
        end
    endtask

    initial begin
        integer p;
        integer stall;
        done   = 1'b0;
        tests  = 0;
        errors = 0;

        // Synchronous active-low reset, two cycles.
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        // Structured matrices: zero, identity, value classes, extrema.
        run_pair("zero x zero",       0, 0, -1);
        run_pair("identity x random", 7, 3, -1);
        run_pair("random x identity", 3, 7, -1);
        run_pair("identity x identity", 7, 7, -1);
        run_pair("positive x positive", 1, 1, -1);
        run_pair("negative x negative", 2, 2, -1);
        run_pair("mixed x mixed",     3, 3, -1);
        run_pair("extrema checker",   4, 4, -1);
        run_pair("all min x all max", 5, 6, -1);
        run_pair("all max x all max", 6, 6, -1);
        run_pair("all min x all min", 5, 5, -1);

        // Fixed-seed random pairs; every third pair stalls at a random step.
        for (p = 0; p < 20; p++) begin
            stall = (p % 3 == 0) ? int'(rnd_u(3 * N - 2)) : -1;
            run_pair("random pair", 3, 3, stall);
        end

        // Mid-stream reset and clear, each followed by a full matrix to prove recovery.
        reset_mid_stream();
        run_pair("after reset recovery", 3, 3, -1);
        clear_mid_stream();
        run_pair("after clr recovery", 3, 3, -1);

        done = 1'b1;
    end
endmodule

module systolic_array_tb;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    integer t_n4,  e_n4;
    integer t_n4w, e_n4w;
    integer t_n2,  e_n2;
    integer t_n1,  e_n1;
    logic   d_n4, d_n4w, d_n2, d_n1;

    sa_harness #(.N(4), .DW(8), .AW(32), .SEED(101)) h_n4 (
        .clk(clk), .tests(t_n4), .errors(e_n4), .done(d_n4));
    sa_harness #(.N(4), .DW(4), .AW(16), .SEED(202)) h_n4w (
        .clk(clk), .tests(t_n4w), .errors(e_n4w), .done(d_n4w));
    sa_harness #(.N(2), .DW(8), .AW(32), .SEED(303)) h_n2 (
        .clk(clk), .tests(t_n2), .errors(e_n2), .done(d_n2));
    sa_harness #(.N(1), .DW(8), .AW(32), .SEED(404)) h_n1 (
        .clk(clk), .tests(t_n1), .errors(e_n1), .done(d_n1));

    integer tests;
    integer errors;
    bit     finished = 1'b0;

    task automatic print_summary;
        begin
            tests  = t_n4 + t_n4w + t_n2 + t_n1;
            errors = e_n4 + e_n4w + e_n2 + e_n1;
            if (errors == 0 && tests > 0)
                $display("SYSTOLIC_ARRAY TEST RESULT: PASS");
            else
                $display("SYSTOLIC_ARRAY TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
        end
    endtask

    // Watchdog: bounded run time, reports FAIL if the harnesses never finish.
    initial begin
        #5000000;
        if (!finished) begin
            finished = 1'b1;
            tests  = t_n4 + t_n4w + t_n2 + t_n1;
            errors = e_n4 + e_n4w + e_n2 + e_n1 + 1;
            $display("FAIL SYSTOLIC_ARRAY watchdog timeout");
            $display("SYSTOLIC_ARRAY TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
            $finish;
        end
    end

    initial begin
        $dumpfile("sim/systolic_array_tb.vcd");
        $dumpvars(0, systolic_array_tb);
        wait (d_n4 && d_n4w && d_n2 && d_n1);
        #1;
        finished = 1'b1;
        print_summary();
        $finish;
    end
endmodule
