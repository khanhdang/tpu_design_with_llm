// Self-checking systolic array testbench: N=4 (default), N=2, N=1, plus a
// narrow DATA_WIDTH/ACC_WIDTH instance.

module sa_case #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int N          = 4,
    parameter int SEED       = 1,
    parameter int NRAND      = 24
) (
    input  logic clk,
    output logic done,
    output int   tests,
    output int   errors
);
    logic                           rst_n, clr, en;
    logic [N*DATA_WIDTH-1:0]        a_left, b_top;
    logic [N*N*ACC_WIDTH-1:0]       c;

    systolic_array #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .ARRAY_SIZE(N)) dut (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
        .a_left(a_left), .b_top(b_top), .c(c));

    // Matrices held as signed 2-D arrays (independent from DUT packing).
    logic signed [DATA_WIDTH-1:0] A [N][N];
    logic signed [DATA_WIDTH-1:0] B [N][N];
    logic signed [ACC_WIDTH-1:0]  C [N][N];
    int                           seed_v;

    localparam logic signed [DATA_WIDTH-1:0] MINV = {1'b1, {(DATA_WIDTH-1){1'b0}}};
    localparam logic signed [DATA_WIDTH-1:0] MAXV = {1'b0, {(DATA_WIDTH-1){1'b1}}};

    // Software reference: nested loops with wide signed intermediates.
    task automatic compute_ref();
        longint signed sum;
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                sum = 0;
                for (int k = 0; k < N; k++)
                    sum = sum + longint'(A[i][k]) * longint'(B[k][j]);
                C[i][j] = ACC_WIDTH'(sum);
            end
    endtask

    task automatic check_all(input string what);
        logic signed [ACC_WIDTH-1:0] got;
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                got = c[(i*N+j)*ACC_WIDTH +: ACC_WIDTH];
                tests++;
                if (got !== C[i][j]) begin
                    errors++;
                    $display("FAIL [%0s] N=%0d DW=%0d C[%0d][%0d]: expected=%0d got=%0d",
                             what, N, DATA_WIDTH, i, j, C[i][j], got);
                end
            end
    endtask

    // Check that every accumulator is zero.
    task automatic check_zero(input string what);
        for (int i = 0; i < N*N; i++) begin
            tests++;
            if (c[i*ACC_WIDTH +: ACC_WIDTH] !== '0) begin
                errors++;
                $display("FAIL [%0s] N=%0d slice %0d expected=0 got=%0d", what, N, i,
                         $signed(c[i*ACC_WIDTH +: ACC_WIDTH]));
            end
        end
    endtask

    // Drive skewed lanes for step t (zero outside range).
    task automatic drive_step(input int t);
        for (int i = 0; i < N; i++) begin
            if (t-i >= 0 && t-i < N) a_left[i*DATA_WIDTH +: DATA_WIDTH] = A[i][t-i];
            else                     a_left[i*DATA_WIDTH +: DATA_WIDTH] = '0;
        end
        for (int j = 0; j < N; j++) begin
            if (t-j >= 0 && t-j < N) b_top[j*DATA_WIDTH +: DATA_WIDTH] = B[t-j][j];
            else                     b_top[j*DATA_WIDTH +: DATA_WIDTH] = '0;
        end
    endtask

    // Clear then run a full multiplication; optionally stall mid-stream.
    task automatic run_matrix(input string what, input int stall_at, input int stall_len);
        compute_ref();
        @(negedge clk); rst_n = 1; clr = 1; en = 0; a_left = '0; b_top = '0;
        @(posedge clk); #1;
        check_zero({what, " clear"});
        for (int t = 0; t <= 3*N-3; t++) begin
            if (t == stall_at) begin
                // Stall: en low with garbage on lanes; state must hold.
                for (int s = 0; s < stall_len; s++) begin
                    @(negedge clk); clr = 0; en = 0;
                    a_left = {N*DATA_WIDTH{1'b1}} ^ a_left; b_top = {N*DATA_WIDTH{1'b1}} ^ b_top;
                    @(posedge clk); #1;
                end
            end
            @(negedge clk); clr = 0; en = 1; drive_step(t);
            @(posedge clk);
        end
        #1;
        check_all(what);
        // Disabled cycles must hold the final result.
        @(negedge clk); en = 0; a_left = {N*DATA_WIDTH{1'b1}}; b_top = {N*DATA_WIDTH{1'b1}};
        @(posedge clk); #1;
        check_all({what, " hold"});
    endtask

    task automatic fill_random();
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                A[i][j] = DATA_WIDTH'($random(seed_v));
                B[i][j] = DATA_WIDTH'($random(seed_v));
            end
    endtask

    initial begin
        done = 0; tests = 0; errors = 0; seed_v = SEED;
        rst_n = 0; clr = 0; en = 0; a_left = '0; b_top = '0;
        repeat (2) @(posedge clk);
        #1;
        check_zero("reset");

        // Zero.
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin A[i][j] = 0; B[i][j] = 0; end
        run_matrix("zero", -1, 0);
        // True identity (diagonal 1) times a random matrix, and vice versa.
        fill_random();
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) A[i][j] = (i == j) ? 1 : 0;
        run_matrix("I*B", -1, 0);
        fill_random();
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) B[i][j] = (i == j) ? 1 : 0;
        run_matrix("A*I", -1, 0);
        // Positive.
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin
            A[i][j] = DATA_WIDTH'(1 + ((i*N + j) % 7));
            B[i][j] = DATA_WIDTH'(2 + ((i + 3*j) % 5));
        end
        run_matrix("positive", -1, 0);
        // Negative.
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin
            A[i][j] = -DATA_WIDTH'(1 + ((i*N + j) % 7));
            B[i][j] = -DATA_WIDTH'(2 + ((i + 3*j) % 5));
        end
        run_matrix("negative", -1, 0);
        // Mixed sign.
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin
            A[i][j] = ((i + j) % 2) ? -DATA_WIDTH'(3 + i) : DATA_WIDTH'(4 + j);
            B[i][j] = ((i * j) % 2) ? DATA_WIDTH'(5 + i) : -DATA_WIDTH'(2 + j);
        end
        run_matrix("mixed", -1, 0);
        // Extrema: all min, all max, min x min, alternating.
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin A[i][j] = MINV; B[i][j] = MINV; end
        run_matrix("min*min", -1, 0);
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin A[i][j] = MAXV; B[i][j] = MAXV; end
        run_matrix("max*max", -1, 0);
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin
            A[i][j] = ((i + j) % 2) ? MINV : MAXV;
            B[i][j] = ((i + j) % 2) ? MAXV : MINV;
        end
        run_matrix("alt extrema", -1, 0);

        // Fixed-seed random pairs.
        for (int r = 0; r < NRAND; r++) begin
            fill_random();
            run_matrix($sformatf("random %0d (seed %0d)", r, SEED), -1, 0);
        end

        // Mid-stream enable stalls.
        fill_random();
        run_matrix("stall mid", (3*N-2)/2, 3);
        fill_random();
        run_matrix("stall first", 1, 2);

        // Clear mid-computation: partially run, then clear must zero everything.
        fill_random();
        compute_ref();
        for (int t = 0; t < ((3*N-2) > 1 ? (3*N-2)/2 + 1 : 1); t++) begin
            @(negedge clk); clr = 0; en = 1; drive_step(t); @(posedge clk);
        end
        @(negedge clk); clr = 1; en = 1;
        @(posedge clk); #1;
        check_zero("clear mid-run");
        // Forwarding registers must be cleared too: run a full multiply straight after.
        run_matrix("after clear", -1, 0);

        // Reset mid-computation.
        fill_random();
        for (int t = 0; t < ((3*N-2) > 1 ? (3*N-2)/2 + 1 : 1); t++) begin
            @(negedge clk); clr = 0; en = 1; drive_step(t); @(posedge clk);
        end
        @(negedge clk); rst_n = 0; en = 1;
        @(posedge clk); #1;
        check_zero("reset mid-run");
        @(negedge clk); rst_n = 1;
        run_matrix("after reset", -1, 0);

        done = 1;
    end
endmodule

module systolic_array_tb;
    logic clk = 0;
    always #5 clk = ~clk;

    logic d4, d2, d1, dn;
    int   t4, e4, t2, e2, t1, e1, tn, en_;

    sa_case #(.DATA_WIDTH(8), .ACC_WIDTH(32), .N(4), .SEED(32'h4444), .NRAND(24)) u_n4 (
        .clk(clk), .done(d4), .tests(t4), .errors(e4));
    sa_case #(.DATA_WIDTH(8), .ACC_WIDTH(32), .N(2), .SEED(32'h2222), .NRAND(24)) u_n2 (
        .clk(clk), .done(d2), .tests(t2), .errors(e2));
    sa_case #(.DATA_WIDTH(8), .ACC_WIDTH(32), .N(1), .SEED(32'h1111), .NRAND(24)) u_n1 (
        .clk(clk), .done(d1), .tests(t1), .errors(e1));
    sa_case #(.DATA_WIDTH(5), .ACC_WIDTH(14), .N(3), .SEED(32'h3333), .NRAND(24)) u_n3w (
        .clk(clk), .done(dn), .tests(tn), .errors(en_));

    initial begin
        $dumpfile("sim/systolic_array_tb.vcd");
        $dumpvars(0, systolic_array_tb);
    end

    initial begin
        repeat (100000) @(posedge clk);
        $display("FAIL watchdog timeout");
        $display("SYSTOLIC_ARRAY TEST RESULT: FAIL");
        $display("Tests: %0d", t4 + t2 + t1 + tn);
        $display("Errors: %0d", e4 + e2 + e1 + en_ + 1);
        $finish;
    end

    initial begin
        int t, e;
        wait (d4 && d2 && d1 && dn);
        @(posedge clk); #1;
        t = t4 + t2 + t1 + tn;
        e = e4 + e2 + e1 + en_;
        $display("========================================");
        if (e == 0 && t > 0) $display("SYSTOLIC_ARRAY TEST RESULT: PASS");
        else                 $display("SYSTOLIC_ARRAY TEST RESULT: FAIL");
        $display("Tests: %0d", t);
        $display("Errors: %0d", e);
        $display("========================================");
        $finish;
    end
endmodule
