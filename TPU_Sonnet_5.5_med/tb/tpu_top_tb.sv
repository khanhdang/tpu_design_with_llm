// Self-checking TPU top testbench: N=4 default, N=2, N=1, and a narrow
// DATA_WIDTH/ACC_WIDTH configuration (N=3, DW=6, AW=16).

module tpu_case #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int N          = 4,
    parameter int SEED       = 1,
    parameter int NRAND      = 50
) (
    input  logic clk,
    output logic finished,
    output int   tests,
    output int   errors
);
    logic                         rst_n, start;
    logic [N*N*DATA_WIDTH-1:0]    a_matrix, b_matrix;
    logic [N*N*ACC_WIDTH-1:0]     c_matrix;
    logic                         busy, done;

    tpu_top #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .ARRAY_SIZE(N)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .a_matrix(a_matrix),
        .b_matrix(b_matrix), .c_matrix(c_matrix), .busy(busy), .done(done));

    logic signed [DATA_WIDTH-1:0] A [N][N];
    logic signed [DATA_WIDTH-1:0] B [N][N];
    logic signed [ACC_WIDTH-1:0]  C [N][N];
    int                           seed_v;
    int                           mat_idx;
    int                           done_cycles;

    localparam logic signed [DATA_WIDTH-1:0] MINV = {1'b1, {(DATA_WIDTH-1){1'b0}}};
    localparam logic signed [DATA_WIDTH-1:0] MAXV = {1'b0, {(DATA_WIDTH-1){1'b1}}};
    localparam int MAX_WAIT = 4*N + 12;

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

    task automatic pack_inputs();
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                a_matrix[(i*N + j)*DATA_WIDTH +: DATA_WIDTH] = A[i][j];
                b_matrix[(i*N + j)*DATA_WIDTH +: DATA_WIDTH] = B[i][j];
            end
    endtask

    task automatic check_c(input string what);
        logic signed [ACC_WIDTH-1:0] got;
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                got = c_matrix[(i*N + j)*ACC_WIDTH +: ACC_WIDTH];
                tests++;
                if (got !== C[i][j]) begin
                    errors++;
                    $display("FAIL [%0s] N=%0d DW=%0d seed=%0d matrix#%0d C[%0d][%0d]: expected=%0d got=%0d",
                             what, N, DATA_WIDTH, SEED, mat_idx, i, j, C[i][j], got);
                end
            end
    endtask

    task automatic check_c_zero(input string what);
        for (int i = 0; i < N*N; i++) begin
            tests++;
            if (c_matrix[i*ACC_WIDTH +: ACC_WIDTH] !== '0) begin
                errors++;
                $display("FAIL [%0s] N=%0d slice %0d expected=0 got=%0d", what, N, i,
                         $signed(c_matrix[i*ACC_WIDTH +: ACC_WIDTH]));
            end
        end
    endtask

    task automatic expect_bit(input string what, input logic got, input logic exp);
        tests++;
        if (got !== exp) begin
            errors++;
            $display("FAIL [%0s] N=%0d seed=%0d matrix#%0d: expected=%b got=%b", what, N, SEED, mat_idx, exp, got);
        end
    endtask

    // Run one transaction. disturb: change inputs after accept; stable: expect
    // c_matrix to hold the old value (prev) until done.
    task automatic run_txn(input string what, input bit disturb);
        logic [N*N*ACC_WIDTH-1:0] old_c;
        int waited;
        compute_ref();
        pack_inputs();
        old_c = c_matrix;
        @(negedge clk); rst_n = 1; start = 1;
        @(posedge clk);                 // accept edge
        @(negedge clk); start = 0;
        if (disturb) begin
            // Corrupt the external inputs; the latched copies must be used.
            a_matrix = ~a_matrix; b_matrix = ~b_matrix;
        end
        waited = 0;
        done_cycles = 0;
        while (done !== 1'b1 && waited < MAX_WAIT) begin
            #1;
            expect_bit({what, " busy while running"}, busy, 1'b1);
            tests++;
            if (c_matrix !== old_c) begin
                errors++;
                $display("FAIL [%0s] c_matrix changed before capture", what);
            end
            if (disturb && (waited % 3 == 0)) begin
                a_matrix = $random(seed_v); b_matrix = $random(seed_v);
            end
            @(negedge clk);
            waited++;
        end
        tests++;
        if (done !== 1'b1) begin
            errors++;
            $display("FAIL [%0s] timeout waiting for done (matrix#%0d)", what, mat_idx);
        end else begin
            // done observed: c_matrix valid now; busy low; done lasts one cycle.
            check_c(what);
            expect_bit({what, " busy at done"}, busy, 1'b0);
            @(negedge clk);
            expect_bit({what, " done width"}, done, 1'b0);
            check_c({what, " stable after done"});
        end
        pack_inputs();   // restore inputs
        mat_idx++;
    endtask

    task automatic fill_random();
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                A[i][j] = DATA_WIDTH'($random(seed_v));
                B[i][j] = DATA_WIDTH'($random(seed_v));
            end
    endtask

    initial begin
        finished = 0; tests = 0; errors = 0; seed_v = SEED; mat_idx = 0;
        rst_n = 0; start = 0; a_matrix = '0; b_matrix = '0;
        repeat (3) @(posedge clk);
        #1;
        check_c_zero("reset output");
        expect_bit("busy after reset", busy, 1'b0);
        expect_bit("done after reset", done, 1'b0);

        // Zero.
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin A[i][j] = 0; B[i][j] = 0; end
        run_txn("zero", 0);
        // Identity (diagonal 1).
        fill_random();
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) A[i][j] = (i == j) ? 1 : 0;
        run_txn("I*B", 0);
        fill_random();
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) B[i][j] = (i == j) ? 1 : 0;
        run_txn("A*I", 0);
        // Positive, negative, mixed.
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin
            A[i][j] = DATA_WIDTH'(1 + ((i*N + j) % 7));
            B[i][j] = DATA_WIDTH'(2 + ((i + 3*j) % 5));
        end
        run_txn("positive", 0);
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin
            A[i][j] = -DATA_WIDTH'(1 + ((i*N + j) % 7));
            B[i][j] = -DATA_WIDTH'(2 + ((i + 3*j) % 5));
        end
        run_txn("negative", 0);
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin
            A[i][j] = ((i + j) % 2) ? -DATA_WIDTH'(3 + i) : DATA_WIDTH'(4 + j);
            B[i][j] = ((i * j) % 2) ? DATA_WIDTH'(5 + i) : -DATA_WIDTH'(2 + j);
        end
        run_txn("mixed", 0);
        // Extrema.
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin A[i][j] = MINV; B[i][j] = MINV; end
        run_txn("min*min", 0);
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin A[i][j] = MAXV; B[i][j] = MAXV; end
        run_txn("max*max", 0);
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin A[i][j] = MINV; B[i][j] = MAXV; end
        run_txn("min*max", 0);
        for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) begin
            A[i][j] = ((i + j) % 2) ? MINV : MAXV;
            B[i][j] = ((i + j) % 2) ? MAXV : MINV;
        end
        run_txn("alt extrema", 0);

        // Random pairs; every third transaction disturbs inputs after accept.
        for (int r = 0; r < NRAND; r++) begin
            fill_random();
            run_txn($sformatf("random %0d", r), (r % 3 == 0));
        end

        // Start asserted while busy is ignored (hold start high through one txn,
        // then verify exactly the expected second result after it).
        fill_random();
        compute_ref(); pack_inputs();
        @(negedge clk); start = 1;
        repeat (3*N + 3) begin
            @(negedge clk);
        end
        // start has been held; the controller restarted back-to-back. Drop start
        // and wait for idle, then confirm the final result matches the inputs.
        start = 0;
        begin
            int w;
            w = 0;
            while (busy !== 1'b0 && w < 6*N + 20) begin @(negedge clk); w++; end
            tests++;
            if (busy !== 1'b0) begin errors++; $display("FAIL [held start] never went idle N=%0d", N); end
        end
        @(negedge clk);
        check_c("held start result");

        // Reset aborts an in-flight transaction and zeros outputs.
        fill_random(); compute_ref(); pack_inputs();
        @(negedge clk); start = 1;
        @(negedge clk); start = 0;
        repeat (N + 1) @(negedge clk);
        rst_n = 0;
        @(posedge clk); #1;
        expect_bit("busy after abort", busy, 1'b0);
        expect_bit("done after abort", done, 1'b0);
        check_c_zero("c after abort");
        @(negedge clk); rst_n = 1;
        repeat (3*N + 6) begin
            @(posedge clk); #1;
            expect_bit("no done after abort", done, 1'b0);
            if (busy !== 1'b0) begin tests++; errors++; $display("FAIL busy after abort"); end
        end
        check_c_zero("c zero after abort idle");
        // Recovery transaction.
        fill_random();
        run_txn("after abort", 0);

        // Consecutive back-to-back transactions with different data.
        for (int r = 0; r < 4; r++) begin
            fill_random();
            run_txn($sformatf("consecutive %0d", r), 0);
        end

        finished = 1;
    end
endmodule

module tpu_top_tb;
    logic clk = 0;
    always #5 clk = ~clk;

    logic d4, d2, d1, dw;
    int   t4, e4, t2, e2, t1, e1, tw, ew;

    tpu_case #(.DATA_WIDTH(8), .ACC_WIDTH(32), .N(4), .SEED(32'h7004), .NRAND(60)) u_n4 (
        .clk(clk), .finished(d4), .tests(t4), .errors(e4));
    tpu_case #(.DATA_WIDTH(8), .ACC_WIDTH(32), .N(2), .SEED(32'h7002), .NRAND(60)) u_n2 (
        .clk(clk), .finished(d2), .tests(t2), .errors(e2));
    tpu_case #(.DATA_WIDTH(8), .ACC_WIDTH(32), .N(1), .SEED(32'h7001), .NRAND(60)) u_n1 (
        .clk(clk), .finished(d1), .tests(t1), .errors(e1));
    tpu_case #(.DATA_WIDTH(6), .ACC_WIDTH(16), .N(3), .SEED(32'h7003), .NRAND(60)) u_w (
        .clk(clk), .finished(dw), .tests(tw), .errors(ew));

    initial begin
        $dumpfile("sim/tpu_top_tb.vcd");
        $dumpvars(0, tpu_top_tb);
    end

    initial begin
        repeat (200000) @(posedge clk);
        $display("FAIL watchdog timeout");
        $display("TPU_TOP TEST RESULT: FAIL");
        $display("Tests: %0d", t4 + t2 + t1 + tw);
        $display("Errors: %0d", e4 + e2 + e1 + ew + 1);
        $finish;
    end

    initial begin
        int t, e;
        wait (d4 && d2 && d1 && dw);
        @(posedge clk); #1;
        t = t4 + t2 + t1 + tw;
        e = e4 + e2 + e1 + ew;
        $display("========================================");
        if (e == 0 && t > 0) $display("TPU_TOP TEST RESULT: PASS");
        else                 $display("TPU_TOP TEST RESULT: FAIL");
        $display("Tests: %0d", t);
        $display("Errors: %0d", e);
        $display("========================================");
        $finish;
    end
endmodule
