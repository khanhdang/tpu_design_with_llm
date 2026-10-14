// Self-checking MAC testbench: two instances (ACC 32 and ACC 16 wraparound).

// One MAC instance with its own independent reference model.
module mac_case #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int SEED       = 1
) (
    input  logic clk,
    output logic done,
    output int   tests,
    output int   errors
);
    logic                         rst_n;
    logic                         clr;
    logic                         en;
    logic signed [DATA_WIDTH-1:0] a;
    logic signed [DATA_WIDTH-1:0] b;
    logic signed [ACC_WIDTH-1:0]  acc;

    mac #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en), .a(a), .b(b), .acc(acc)
    );

    // Reference accumulator, wide intermediate, wrapped to ACC_WIDTH on store.
    logic signed [ACC_WIDTH-1:0] ref_acc;
    longint signed               wide;
    int                          seed_v;

    task automatic check(input string what);
        logic signed [ACC_WIDTH-1:0] got;
        got = acc;
        tests++;
        if (got !== ref_acc) begin
            errors++;
            $display("FAIL [%0s] DW=%0d AW=%0d rst_n=%b clr=%b en=%b a=%0d b=%0d: expected=%0d got=%0d",
                     what, DATA_WIDTH, ACC_WIDTH, rst_n, clr, en, a, b, ref_acc, got);
        end
    endtask

    // Drive on falling edge, update reference at the rising edge, check after settling.
    task automatic cycle(input logic r_n, input logic c, input logic e,
                         input logic signed [DATA_WIDTH-1:0] av,
                         input logic signed [DATA_WIDTH-1:0] bv,
                         input string what);
        @(negedge clk);
        rst_n = r_n; clr = c; en = e; a = av; b = bv;
        @(posedge clk);
        if (!r_n)      ref_acc = '0;
        else if (c)    ref_acc = '0;
        else if (e) begin
            wide    = longint'(av) * longint'(bv);
            ref_acc = ref_acc + ACC_WIDTH'(wide);
        end
        #1;
        check(what);
    endtask

    localparam logic signed [DATA_WIDTH-1:0] MINV = {1'b1, {(DATA_WIDTH-1){1'b0}}};
    localparam logic signed [DATA_WIDTH-1:0] MAXV = {1'b0, {(DATA_WIDTH-1){1'b1}}};

    initial begin
        done = 0; tests = 0; errors = 0;
        rst_n = 0; clr = 0; en = 0; a = '0; b = '0; ref_acc = '0;
        seed_v = SEED;

        // Reset with nonzero data and enable.
        cycle(1'b0, 1'b0, 1'b1, 5, 5, "reset");
        cycle(1'b0, 1'b1, 1'b1, 5, 5, "reset+clr+en");
        // Zero product.
        cycle(1'b1, 1'b0, 1'b1, 0, 7, "zero a");
        cycle(1'b1, 1'b0, 1'b1, 7, 0, "zero b");
        // Known products, clearing between independent cases.
        cycle(1'b1, 1'b0, 1'b1, 3, 4, "3*4");                 // 12
        cycle(1'b1, 1'b1, 1'b0, 0, 0, "clr en=0");
        cycle(1'b1, 1'b0, 1'b1, -3, 4, "(-3)*4");             // -12
        cycle(1'b1, 1'b1, 1'b0, 0, 0, "clr en=0");
        cycle(1'b1, 1'b0, 1'b1, 3, -4, "3*(-4)");             // -12
        cycle(1'b1, 1'b1, 1'b0, 0, 0, "clr en=0");
        cycle(1'b1, 1'b0, 1'b1, -3, -4, "(-3)*(-4)");         // 12
        cycle(1'b1, 1'b1, 1'b0, 0, 0, "clr en=0");
        cycle(1'b1, 1'b0, 1'b1, MINV, MAXV, "min*max");
        cycle(1'b1, 1'b1, 1'b0, 0, 0, "clr en=0");
        cycle(1'b1, 1'b0, 1'b1, MINV, MINV, "min*min");
        cycle(1'b1, 1'b1, 1'b0, 0, 0, "clr en=0");
        cycle(1'b1, 1'b0, 1'b1, MAXV, MAXV, "max*max");
        // Repeated accumulation.
        repeat (4) cycle(1'b1, 1'b0, 1'b1, MINV, MINV, "repeat min*min");
        // Enable hold with changing operands.
        cycle(1'b1, 1'b0, 1'b0, 9, 9, "hold");
        cycle(1'b1, 1'b0, 1'b0, MAXV, MINV, "hold2");
        // clr overrides en.
        cycle(1'b1, 1'b1, 1'b1, 100 % 127, 5, "clr over en");
        cycle(1'b1, 1'b0, 1'b1, 6, 7, "after clr");
        // Reset overrides all.
        cycle(1'b0, 1'b1, 1'b1, 6, 7, "reset over all");
        cycle(1'b1, 1'b0, 1'b1, 1, 1, "after reset");

        // Fixed-seed random operations.
        for (int i = 0; i < 400; i++) begin
            logic signed [DATA_WIDTH-1:0] ra, rb;
            logic [2:0] ctl;
            ra  = DATA_WIDTH'($random(seed_v));
            rb  = DATA_WIDTH'($random(seed_v));
            ctl = 3'($random(seed_v));
            // Bias toward enabled accumulation; occasional clr / reset.
            cycle((ctl != 3'd0), (ctl == 3'd1), (ctl != 3'd2), ra, rb, "random");
        end
        done = 1;
    end
endmodule

module mac_tb;
    logic clk = 0;
    always #5 clk = ~clk;

    logic w_rst_n = 0, w_clr = 0, w_en = 0, wrap_done = 0;
    logic done32, done16;
    int   tests32, errors32, tests16, errors16;

    mac_case #(.DATA_WIDTH(8), .ACC_WIDTH(32), .SEED(32'h1234)) u32 (
        .clk(clk), .done(done32), .tests(tests32), .errors(errors32));
    mac_case #(.DATA_WIDTH(8), .ACC_WIDTH(16), .SEED(32'h5678)) u16 (
        .clk(clk), .done(done16), .tests(tests16), .errors(errors16));

    // Explicit wraparound check on the 16-bit instance, driven after the
    // random phase: repeated 16384 products must wrap 32768 to -32768.
    int extra_tests = 0, extra_errors = 0;

    initial begin
        $dumpfile("sim/mac_tb.vcd");
        $dumpvars(0, mac_tb);
    end

    // Watchdog.
    initial begin
        repeat (20000) @(posedge clk);
        $display("FAIL watchdog timeout");
        $display("MAC TEST RESULT: FAIL");
        $display("Tests: %0d", tests32 + tests16 + extra_tests);
        $display("Errors: %0d", errors32 + errors16 + extra_errors + 1);
        $finish;
    end

    initial begin
        int total_t, total_e;
        wait (done32 && done16);
        @(posedge clk); #1;
        // Wrap test with an independent local 16-bit MAC instance below.
        wait (wrap_done);
        total_t = tests32 + tests16 + extra_tests;
        total_e = errors32 + errors16 + extra_errors;
        $display("========================================");
        if (total_e == 0 && total_t > 0) $display("MAC TEST RESULT: PASS");
        else                             $display("MAC TEST RESULT: FAIL");
        $display("Tests: %0d", total_t);
        $display("Errors: %0d", total_e);
        $display("========================================");
        $finish;
    end

    // Dedicated 16-bit wraparound DUT.
    logic signed [7:0]  w_a = 0, w_b = 0;
    logic signed [15:0] w_acc;
    mac #(.DATA_WIDTH(8), .ACC_WIDTH(16)) wrap_dut (
        .clk(clk), .rst_n(w_rst_n), .clr(w_clr), .en(w_en), .a(w_a), .b(w_b), .acc(w_acc));

    task automatic wcheck(input logic signed [15:0] exp, input string what);
        #1;
        extra_tests++;
        if (w_acc !== exp) begin
            extra_errors++;
            $display("FAIL [%0s]: expected=%0d got=%0d", what, exp, w_acc);
        end
    endtask

    initial begin
        @(negedge clk); w_rst_n = 0; @(posedge clk); wcheck(16'sd0, "wrap reset");
        @(negedge clk); w_rst_n = 1; w_en = 1; w_a = -8'sd128; w_b = -8'sd128; // 16384
        @(posedge clk); wcheck(16'sd16384, "1x16384");
        @(posedge clk); wcheck(-16'sd32768, "2x16384 = 32768 wraps to -32768");
        @(posedge clk); wcheck(-16'sd16384, "3x16384");
        @(posedge clk); wcheck(16'sd0, "4x16384 wraps to 0");
        @(negedge clk); w_en = 0;
        @(posedge clk); wcheck(16'sd0, "hold");
        wrap_done = 1;
    end
endmodule
