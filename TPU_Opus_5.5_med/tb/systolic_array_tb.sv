// Self-checking testbench for systolic_array.
// Several real parameterizations (N=4, N=2, N=1, N=3 with DATA_WIDTH=4, and an
// ACC_WIDTH=16 wrap case) run in parallel harnesses. Each harness drives the
// architecture's skewed lanes and checks every accumulator after every compute
// edge against an independent signed nested-loop reference.

module array_harness #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int ARRAY_SIZE = 4,
    parameter int NRAND      = 20,
    parameter int SEED       = 1
) (
    input  logic   clk,
    output integer tests,
    output integer errors,
    output logic   finished
);

    localparam int N = ARRAY_SIZE;
    localparam int LAST_STEP = 3*N - 3;
    localparam logic signed [DATA_WIDTH-1:0] MAXV = {1'b0, {(DATA_WIDTH-1){1'b1}}};
    localparam logic signed [DATA_WIDTH-1:0] MINV = {1'b1, {(DATA_WIDTH-1){1'b0}}};

    localparam int K_ZERO = 0, K_IDENT_A = 1, K_IDENT_B = 2, K_POS = 3, K_NEG = 4,
                   K_MIXED = 5, K_MINMIN = 6, K_MINMAX = 7, K_RAND = 8;

    logic                              rst_n, clr, en;
    logic [N*DATA_WIDTH-1:0]           a_left, b_top;
    logic [N*N*ACC_WIDTH-1:0]          c;

    systolic_array #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .ARRAY_SIZE(N)) dut (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
        .a_left(a_left), .b_top(b_top), .c(c)
    );

    // Test matrices (signed element values) and bookkeeping.
    integer ma [0:N-1][0:N-1];
    integer mb [0:N-1][0:N-1];
    integer seed;
    integer case_id;
    string  case_name;

    function automatic integer rand_elem(input int kind);
        logic signed [DATA_WIDTH-1:0] v;
        v = $random(seed);
        case (kind)
            K_POS:   v = v & MAXV;                 // 0 .. MAX
            K_NEG:   v = v | MINV;                 // MIN .. -1
            default: ;                             // full signed range
        endcase
        return v;
    endfunction

    task automatic fill(input int kind);
        integer i, j;
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                case (kind)
                    K_ZERO:    begin ma[i][j] = 0; mb[i][j] = 0; end
                    K_IDENT_A: begin ma[i][j] = (i == j); mb[i][j] = rand_elem(K_RAND); end
                    K_IDENT_B: begin ma[i][j] = rand_elem(K_RAND); mb[i][j] = (i == j); end
                    K_POS:     begin ma[i][j] = rand_elem(K_POS); mb[i][j] = rand_elem(K_POS); end
                    K_NEG:     begin ma[i][j] = rand_elem(K_NEG); mb[i][j] = rand_elem(K_NEG); end
                    K_MIXED:   begin
                        ma[i][j] = ((i + j) % 2) ? rand_elem(K_NEG) : rand_elem(K_POS);
                        mb[i][j] = ((i + j) % 2) ? rand_elem(K_POS) : rand_elem(K_NEG);
                    end
                    K_MINMIN:  begin ma[i][j] = MINV; mb[i][j] = MINV; end
                    K_MINMAX:  begin ma[i][j] = MINV; mb[i][j] = MAXV; end
                    default:   begin ma[i][j] = rand_elem(K_RAND); mb[i][j] = rand_elem(K_RAND); end
                endcase
            end
    endtask

    // Expected C[i][j] counting only products k with k+i+j <= t
    // (t = LAST_STEP gives the full matrix product). Wraps to ACC_WIDTH.
    function automatic logic signed [ACC_WIDTH-1:0] expected(input integer i, input integer j,
                                                             input integer t);
        longint sum;
        integer k;
        sum = 0;
        for (k = 0; k < N; k = k + 1)
            if (k + i + j <= t)
                sum = sum + longint'(ma[i][k]) * longint'(mb[k][j]);
        return sum;
    endfunction

    function automatic logic signed [ACC_WIDTH-1:0] got(input integer i, input integer j);
        return c[(i*N + j)*ACC_WIDTH +: ACC_WIDTH];
    endfunction

    // Compare all N*N accumulators against the reference after step t.
    task automatic check_all(input integer t, input string phase);
        integer i, j;
        logic signed [ACC_WIDTH-1:0] exp, act;
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                exp   = expected(i, j, t);
                act   = got(i, j);
                tests = tests + 1;
                if (act !== exp) begin
                    errors = errors + 1;
                    $display("FAIL ARRAY[N=%0d,DW=%0d,AW=%0d] case %0d (%s) %s step=%0d C[%0d][%0d]: expected=%0d got=%0d (seed=%0d)",
                             N, DATA_WIDTH, ACC_WIDTH, case_id, case_name, phase, t, i, j,
                             exp, act, SEED);
                end
            end
    endtask

    task automatic check_zero(input string phase);
        integer i, j;
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                tests = tests + 1;
                if (got(i, j) !== '0) begin
                    errors = errors + 1;
                    $display("FAIL ARRAY[N=%0d] %s: C[%0d][%0d] expected=0 got=%0d",
                             N, phase, i, j, got(i, j));
                end
            end
    endtask

    task automatic drive_lanes(input integer t);
        integer i, j;
        for (i = 0; i < N; i = i + 1)
            a_left[i*DATA_WIDTH +: DATA_WIDTH] = (t - i >= 0 && t - i < N) ? ma[i][t-i] : 0;
        for (j = 0; j < N; j = j + 1)
            b_top[j*DATA_WIDTH +: DATA_WIDTH]  = (t - j >= 0 && t - j < N) ? mb[t-j][j] : 0;
    endtask

    task automatic do_clear();
        @(negedge clk);
        clr = 1'b1; en = 1'b0;
        a_left = $random(seed); b_top = $random(seed);   // must be ignored
        @(posedge clk);
        #1 check_zero("after clear");
        @(negedge clk);
        clr = 1'b0;
    endtask

    // Run a full skewed transaction. stall_at >= 0 inserts stall_len en=0 cycles
    // (with garbage on the lanes) after compute step stall_at.
    task automatic run_matrix(input integer stall_at, input integer stall_len);
        integer t, s;
        do_clear();
        for (t = 0; t <= LAST_STEP; t = t + 1) begin
            @(negedge clk);
            en = 1'b1;
            drive_lanes(t);
            @(posedge clk);
            #1 check_all(t, "compute");
            if (t == stall_at) begin
                for (s = 0; s < stall_len; s = s + 1) begin
                    @(negedge clk);
                    en = 1'b0;
                    a_left = $random(seed);
                    b_top  = $random(seed);
                    @(posedge clk);
                    #1 check_all(t, "stall");
                end
            end
        end
        @(negedge clk);
        en = 1'b0;
        a_left = '0; b_top = '0;
        @(posedge clk);
        #1 check_all(LAST_STEP, "final hold");
    endtask

    task automatic run_case(input string name, input int kind,
                            input integer stall_at, input integer stall_len);
        case_name = name;
        fill(kind);
        run_matrix(stall_at, stall_len);
        case_id = case_id + 1;
    endtask

    integer r, t;

    initial begin
        tests    = 0;
        errors   = 0;
        finished = 1'b0;
        seed     = SEED;
        case_id  = 0;
        rst_n = 1'b0; clr = 1'b0; en = 1'b0; a_left = '0; b_top = '0;

        repeat (2) @(posedge clk);
        #1 check_zero("after reset");
        @(negedge clk);
        rst_n = 1'b1;

        run_case("zero",          K_ZERO,    -1, 0);
        run_case("identity A",    K_IDENT_A, -1, 0);
        run_case("identity B",    K_IDENT_B, -1, 0);
        run_case("positive",      K_POS,     -1, 0);
        run_case("negative",      K_NEG,     -1, 0);
        run_case("mixed sign",    K_MIXED,   -1, 0);
        run_case("MIN*MIN",       K_MINMIN,  -1, 0);
        run_case("MIN*MAX",       K_MINMAX,  -1, 0);
        run_case("stall mid",     K_RAND,    N - 1, 3);
        run_case("stall first",   K_RAND,    0, 1);
        for (r = 0; r < NRAND; r = r + 1)
            run_case("random", K_RAND, -1, 0);

        // Clear in the middle of a transaction, then a fresh transaction must not
        // see stale forwarding registers or accumulators.
        case_name = "mid-run clear";
        fill(K_RAND);
        do_clear();
        for (t = 0; t < N; t = t + 1) begin
            @(negedge clk); en = 1'b1; drive_lanes(t);
            @(posedge clk);
        end
        run_case("after mid-run clear", K_RAND, -1, 0);

        // Synchronous reset in the middle of a transaction.
        fill(K_MINMIN);
        do_clear();
        for (t = 0; t < N; t = t + 1) begin
            @(negedge clk); en = 1'b1; drive_lanes(t);
            @(posedge clk);
        end
        @(negedge clk);
        rst_n = 1'b0; en = 1'b1; a_left = $random(seed); b_top = $random(seed);
        @(posedge clk);
        #1 check_zero("reset mid-run");
        @(negedge clk);
        rst_n = 1'b1; en = 1'b0;
        // Without an intervening clear, an enabled zero-lane cycle would expose any
        // forwarding register that survived reset (stale A meets stale B).
        a_left = '0; b_top = '0; en = 1'b1;
        @(posedge clk);
        #1 check_zero("enabled zero lanes after reset");
        @(negedge clk);
        en = 1'b0;
        run_case("after reset", K_RAND, -1, 0);

        finished = 1'b1;
    end

endmodule

module systolic_array_tb;

    localparam int MAX_CYCLES = 20000;

    logic   clk = 1'b0;
    always #5 clk = ~clk;

    integer t4, e4, t2, e2, t1, e1, t3, e3, tw, ew;
    logic   f4, f2, f1, f3, fw;
    integer cycles = 0;
    logic   reported = 1'b0;

    array_harness #(.DATA_WIDTH(8), .ACC_WIDTH(32), .ARRAY_SIZE(4), .NRAND(25), .SEED(32'hA4A4)) h_n4 (
        .clk(clk), .tests(t4), .errors(e4), .finished(f4)
    );
    array_harness #(.DATA_WIDTH(8), .ACC_WIDTH(32), .ARRAY_SIZE(2), .NRAND(20), .SEED(32'hB2B2)) h_n2 (
        .clk(clk), .tests(t2), .errors(e2), .finished(f2)
    );
    array_harness #(.DATA_WIDTH(8), .ACC_WIDTH(32), .ARRAY_SIZE(1), .NRAND(20), .SEED(32'hC1C1)) h_n1 (
        .clk(clk), .tests(t1), .errors(e1), .finished(f1)
    );
    array_harness #(.DATA_WIDTH(4), .ACC_WIDTH(12), .ARRAY_SIZE(3), .NRAND(20), .SEED(32'hD3D3)) h_n3_dw4 (
        .clk(clk), .tests(t3), .errors(e3), .finished(f3)
    );
    array_harness #(.DATA_WIDTH(8), .ACC_WIDTH(16), .ARRAY_SIZE(4), .NRAND(20), .SEED(32'hE16E)) h_n4_aw16 (
        .clk(clk), .tests(tw), .errors(ew), .finished(fw)
    );

    initial begin
        $dumpfile("sim/systolic_array_tb.vcd");
        $dumpvars(0, systolic_array_tb);
    end

    task automatic summary(input integer tests, input integer errors);
        if (!reported) begin
            reported = 1'b1;
            $display("========================================");
            if (errors == 0 && tests > 0) $display("SYSTOLIC_ARRAY TEST RESULT: PASS");
            else                          $display("SYSTOLIC_ARRAY TEST RESULT: FAIL");
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
            summary(t4 + t2 + t1 + t3 + tw, e4 + e2 + e1 + e3 + ew + 1);
        end
    end

    initial begin
        wait (f4 === 1'b1 && f2 === 1'b1 && f1 === 1'b1 && f3 === 1'b1 && fw === 1'b1);
        #1;
        $display("ARRAY config N=4 DW=8 AW=32: checks=%0d mismatches=%0d", t4, e4);
        $display("ARRAY config N=2 DW=8 AW=32: checks=%0d mismatches=%0d", t2, e2);
        $display("ARRAY config N=1 DW=8 AW=32: checks=%0d mismatches=%0d", t1, e1);
        $display("ARRAY config N=3 DW=4 AW=12: checks=%0d mismatches=%0d", t3, e3);
        $display("ARRAY config N=4 DW=8 AW=16: checks=%0d mismatches=%0d", tw, ew);
        summary(t4 + t2 + t1 + t3 + tw, e4 + e2 + e1 + e3 + ew);
    end

endmodule
