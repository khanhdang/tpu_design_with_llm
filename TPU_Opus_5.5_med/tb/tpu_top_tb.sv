// Self-checking testbench for tpu_top.
// Harnesses: N=4 DW=8 AW=32 (default, 60 random pairs), N=2 DW=8 AW=32,
// N=1 DW=8 AW=32, N=2 DW=5 AW=12, N=3 DW=4 AW=12. Expected products come from
// independent signed nested loops; every c_matrix slice is compared with !==.

module tpu_harness #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int ARRAY_SIZE = 4,
    parameter int NRAND      = 50,
    parameter int SEED       = 1
) (
    input  logic   clk,
    output integer tests,
    output integer errors,
    output logic   finished
);

    localparam int N       = ARRAY_SIZE;
    localparam int LATENCY = 3*N + 1;   // accept edge .. done visible (edges)
    localparam int MAXWAIT = 3*N + 20;  // bounded wait for done
    localparam logic signed [DATA_WIDTH-1:0] MAXV = {1'b0, {(DATA_WIDTH-1){1'b1}}};
    localparam logic signed [DATA_WIDTH-1:0] MINV = {1'b1, {(DATA_WIDTH-1){1'b0}}};

    localparam int K_ZERO = 0, K_IDENT_A = 1, K_IDENT_B = 2, K_IDENT_AB = 3, K_POS = 4,
                   K_NEG = 5, K_MIXED = 6, K_MINMIN = 7, K_MINMAX = 8, K_MAXMAX = 9,
                   K_RAND = 10;

    logic                         rst_n, start;
    logic [N*N*DATA_WIDTH-1:0]    a_matrix, b_matrix;
    logic [N*N*ACC_WIDTH-1:0]     c_matrix;
    logic                         busy, done;

    tpu_top #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .ARRAY_SIZE(N)) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .a_matrix(a_matrix), .b_matrix(b_matrix), .c_matrix(c_matrix),
        .busy(busy), .done(done)
    );

    integer ma [0:N-1][0:N-1];
    integer mb [0:N-1][0:N-1];
    logic [N*N*ACC_WIDTH-1:0] exp_c;   // expected result of the current transaction
    logic [N*N*ACC_WIDTH-1:0] pub_c;   // last result the DUT should be publishing
    integer seed;
    integer case_id;
    string  case_name;

    task automatic fail_msg(input string what);
        errors = errors + 1;
        $display("FAIL TPU[N=%0d,DW=%0d,AW=%0d] case %0d (%s) %s @%0t: busy=%b done=%b (seed=%0d)",
                 N, DATA_WIDTH, ACC_WIDTH, case_id, case_name, what, $time, busy, done, SEED);
    endtask

    task automatic check_bit(input logic actual, input logic expected, input string what);
        tests = tests + 1;
        if (actual !== expected) begin
            fail_msg(what);
            $display("     expected=%b got=%b", expected, actual);
        end
    endtask

    // Compare every c_matrix slice to the given packed expectation.
    task automatic check_c(input logic [N*N*ACC_WIDTH-1:0] expected, input string what);
        integer i, j;
        logic signed [ACC_WIDTH-1:0] e, g;
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                e = expected[(i*N + j)*ACC_WIDTH +: ACC_WIDTH];
                g = c_matrix[(i*N + j)*ACC_WIDTH +: ACC_WIDTH];
                tests = tests + 1;
                if (g !== e) begin
                    errors = errors + 1;
                    $display("FAIL TPU[N=%0d,DW=%0d,AW=%0d] case %0d (%s) %s C[%0d][%0d]: expected=%0d got=%0d (seed=%0d)",
                             N, DATA_WIDTH, ACC_WIDTH, case_id, case_name, what, i, j, e, g, SEED);
                end
            end
    endtask

    function automatic integer rand_elem(input int kind);
        logic signed [DATA_WIDTH-1:0] v;
        v = $random(seed);
        case (kind)
            K_POS:   v = v & MAXV;
            K_NEG:   v = v | MINV;
            default: ;
        endcase
        return v;
    endfunction

    task automatic fill(input int kind);
        integer i, j;
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                case (kind)
                    K_ZERO:     begin ma[i][j] = 0; mb[i][j] = 0; end
                    K_IDENT_A:  begin ma[i][j] = (i == j); mb[i][j] = rand_elem(K_RAND); end
                    K_IDENT_B:  begin ma[i][j] = rand_elem(K_RAND); mb[i][j] = (i == j); end
                    K_IDENT_AB: begin ma[i][j] = (i == j); mb[i][j] = (i == j); end
                    K_POS:      begin ma[i][j] = rand_elem(K_POS); mb[i][j] = rand_elem(K_POS); end
                    K_NEG:      begin ma[i][j] = rand_elem(K_NEG); mb[i][j] = rand_elem(K_NEG); end
                    K_MIXED:    begin
                        ma[i][j] = ((i + j) % 2) ? rand_elem(K_NEG) : rand_elem(K_POS);
                        mb[i][j] = ((i + j) % 2) ? rand_elem(K_POS) : rand_elem(K_NEG);
                    end
                    K_MINMIN:   begin ma[i][j] = MINV; mb[i][j] = MINV; end
                    K_MINMAX:   begin ma[i][j] = MINV; mb[i][j] = MAXV; end
                    K_MAXMAX:   begin ma[i][j] = MAXV; mb[i][j] = MAXV; end
                    default:    begin ma[i][j] = rand_elem(K_RAND); mb[i][j] = rand_elem(K_RAND); end
                endcase
            end
    endtask

    // Independent reference: C[i][j] = sum_k A[i][k]*B[k][j], wrapped to ACC_WIDTH.
    task automatic compute_expected();
        integer i, j, k;
        longint sum;
        logic signed [ACC_WIDTH-1:0] w;
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                sum = 0;
                for (k = 0; k < N; k = k + 1)
                    sum = sum + longint'(ma[i][k]) * longint'(mb[k][j]);
                w = sum;
                exp_c[(i*N + j)*ACC_WIDTH +: ACC_WIDTH] = w;
            end
    endtask

    task automatic drive_matrices();
        integer i, j;
        logic signed [DATA_WIDTH-1:0] va, vb;
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                va = ma[i][j];
                vb = mb[i][j];
                a_matrix[(i*N + j)*DATA_WIDTH +: DATA_WIDTH] = va;
                b_matrix[(i*N + j)*DATA_WIDTH +: DATA_WIDTH] = vb;
            end
    endtask

    task automatic scramble_inputs();
        integer i;
        for (i = 0; i < N*N; i = i + 1) begin
            a_matrix[i*DATA_WIDTH +: DATA_WIDTH] = $random(seed);
            b_matrix[i*DATA_WIDTH +: DATA_WIDTH] = $random(seed);
        end
    endtask

    // One full transaction. Requests the transaction on the next falling edge
    // (so a call right after done tests the first idle edge), scrambles the
    // inputs after accept, optionally raises start while busy, checks that the
    // old result stays published until done, then checks latency and every slice.
    task automatic run_txn(input string name, input int kind, input logic busy_requests);
        integer cyc;
        case_name = name;
        fill(kind);
        compute_expected();
        @(negedge clk);
        start = 1'b1;
        drive_matrices();
        @(posedge clk);
        #1;
        cyc = 1;
        check_bit(busy, 1'b1, "busy after accept");
        check_bit(done, 1'b0, "no done right after accept");
        while (done !== 1'b1 && cyc < MAXWAIT) begin
            @(negedge clk);
            start = busy_requests ? $random(seed) : 1'b0;
            scramble_inputs();
            @(posedge clk);
            #1;
            cyc = cyc + 1;
            if (done !== 1'b1) begin
                check_bit(busy, 1'b1, "busy while running");
                check_c(pub_c, "old result stable before capture");
            end
        end
        tests = tests + 1;
        if (done !== 1'b1 || cyc != LATENCY) begin
            errors = errors + 1;
            $display("FAIL TPU[N=%0d] case %0d (%s): done after %0d edges, expected %0d (done=%b, seed=%0d)",
                     N, case_id, case_name, cyc, LATENCY, done, SEED);
        end
        check_bit(busy, 1'b0, "idle when done");
        check_c(exp_c, "result");
        pub_c = exp_c;
        case_id = case_id + 1;
    endtask

    // One idle cycle with start low: done must be clear and results held.
    task automatic idle_check(input string what);
        @(negedge clk);
        start = 1'b0;
        scramble_inputs();
        @(posedge clk);
        #1;
        check_bit(done, 1'b0, what);
        check_bit(busy, 1'b0, what);
        check_c(pub_c, what);
    endtask

    integer r, t;

    initial begin
        tests    = 0;
        errors   = 0;
        finished = 1'b0;
        seed     = SEED;
        case_id  = 0;
        case_name = "reset";
        rst_n = 1'b0; start = 1'b0; a_matrix = '0; b_matrix = '0;
        pub_c = '0;

        repeat (2) @(posedge clk);
        #1;
        check_c('0, "after reset");
        check_bit(busy, 1'b0, "busy after reset");
        check_bit(done, 1'b0, "done after reset");
        @(negedge clk);
        rst_n = 1'b1;

        run_txn("zero",          K_ZERO,     1'b0); idle_check("done is one cycle");
        run_txn("identity A",    K_IDENT_A,  1'b0); idle_check("done is one cycle");
        run_txn("identity B",    K_IDENT_B,  1'b0); idle_check("done is one cycle");
        run_txn("identity A*B",  K_IDENT_AB, 1'b1); idle_check("done is one cycle");
        run_txn("positive",      K_POS,      1'b1); idle_check("done is one cycle");
        run_txn("negative",      K_NEG,      1'b1); idle_check("done is one cycle");
        run_txn("mixed sign",    K_MIXED,    1'b1); idle_check("done is one cycle");
        run_txn("MIN*MIN",       K_MINMIN,   1'b0); idle_check("done is one cycle");
        run_txn("MIN*MAX",       K_MINMAX,   1'b0); idle_check("done is one cycle");
        run_txn("MAX*MAX",       K_MAXMAX,   1'b0); idle_check("done is one cycle");

        // Random pairs, alternating back-to-back (first idle edge) and gapped.
        for (r = 0; r < NRAND; r = r + 1) begin
            run_txn("random", K_RAND, r[0]);
            if (r % 3 == 2) idle_check("idle between random");
        end
        idle_check("after random");

        // Reset in the middle of a transaction aborts it and zeros the outputs.
        case_name = "reset abort";
        fill(K_MINMIN);
        @(negedge clk);
        start = 1'b1;
        drive_matrices();
        for (t = 0; t < N + 1; t = t + 1) begin
            @(posedge clk);
            @(negedge clk);
            start = 1'b0;
        end
        rst_n = 1'b0;
        @(posedge clk);
        #1;
        pub_c = '0;
        check_c(pub_c, "outputs zeroed by reset");
        check_bit(busy, 1'b0, "busy cleared by reset");
        check_bit(done, 1'b0, "done cleared by reset");
        @(negedge clk);
        rst_n = 1'b1;
        for (t = 0; t < 3*N + 4; t = t + 1)
            idle_check("no completion after reset abort");
        run_txn("after reset abort", K_RAND, 1'b1);
        run_txn("back-to-back after abort", K_MIXED, 1'b0);
        idle_check("final idle");

        finished = 1'b1;
    end

endmodule

module tpu_top_tb;

    localparam int MAX_CYCLES = 20000;

    logic   clk = 1'b0;
    always #5 clk = ~clk;

    integer t0, e0, t1, e1, t2, e2, t3, e3, t4, e4;
    logic   f0, f1, f2, f3, f4;
    integer cycles = 0;
    logic   reported = 1'b0;

    tpu_harness #(.DATA_WIDTH(8), .ACC_WIDTH(32), .ARRAY_SIZE(4), .NRAND(60), .SEED(32'h7A0C)) h_n4 (
        .clk(clk), .tests(t0), .errors(e0), .finished(f0)
    );
    tpu_harness #(.DATA_WIDTH(8), .ACC_WIDTH(32), .ARRAY_SIZE(2), .NRAND(30), .SEED(32'h7A02)) h_n2 (
        .clk(clk), .tests(t1), .errors(e1), .finished(f1)
    );
    tpu_harness #(.DATA_WIDTH(8), .ACC_WIDTH(32), .ARRAY_SIZE(1), .NRAND(30), .SEED(32'h7A01)) h_n1 (
        .clk(clk), .tests(t2), .errors(e2), .finished(f2)
    );
    tpu_harness #(.DATA_WIDTH(5), .ACC_WIDTH(12), .ARRAY_SIZE(2), .NRAND(30), .SEED(32'h7A25)) h_n2_dw5 (
        .clk(clk), .tests(t3), .errors(e3), .finished(f3)
    );
    tpu_harness #(.DATA_WIDTH(4), .ACC_WIDTH(12), .ARRAY_SIZE(3), .NRAND(30), .SEED(32'h7A34)) h_n3_dw4 (
        .clk(clk), .tests(t4), .errors(e4), .finished(f4)
    );

    initial begin
        $dumpfile("sim/tpu_top_tb.vcd");
        $dumpvars(0, tpu_top_tb);
    end

    task automatic summary(input integer tests, input integer errors);
        if (!reported) begin
            reported = 1'b1;
            $display("========================================");
            if (errors == 0 && tests > 0) $display("TPU_TOP TEST RESULT: PASS");
            else                          $display("TPU_TOP TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
            $display("========================================");
            $finish;
        end
    endtask

    always @(posedge clk) begin
        cycles <= cycles + 1;
        if (cycles >= MAX_CYCLES) begin
            $display("FAIL watchdog: timeout after %0d cycles", cycles);
            summary(t0 + t1 + t2 + t3 + t4, e0 + e1 + e2 + e3 + e4 + 1);
        end
    end

    initial begin
        wait (f0 === 1'b1 && f1 === 1'b1 && f2 === 1'b1 && f3 === 1'b1 && f4 === 1'b1);
        #1;
        $display("TPU_TOP config N=4 DW=8 AW=32: checks=%0d mismatches=%0d", t0, e0);
        $display("TPU_TOP config N=2 DW=8 AW=32: checks=%0d mismatches=%0d", t1, e1);
        $display("TPU_TOP config N=1 DW=8 AW=32: checks=%0d mismatches=%0d", t2, e2);
        $display("TPU_TOP config N=2 DW=5 AW=12: checks=%0d mismatches=%0d", t3, e3);
        $display("TPU_TOP config N=3 DW=4 AW=12: checks=%0d mismatches=%0d", t4, e4);
        summary(t0 + t1 + t2 + t3 + t4, e0 + e1 + e2 + e3 + e4);
    end

endmodule
