// Self-checking PE testbench: two instances (default and DATA_WIDTH=5/ACC_WIDTH=12).

module pe_case #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int SEED       = 1
) (
    input  logic clk,
    output logic done,
    output int   tests,
    output int   errors
);
    logic                         rst_n, clr, en;
    logic signed [DATA_WIDTH-1:0] a_in, b_in, a_out, b_out;
    logic signed [ACC_WIDTH-1:0]  acc;

    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
        .a_in(a_in), .b_in(b_in), .a_out(a_out), .b_out(b_out), .acc(acc));

    logic signed [ACC_WIDTH-1:0]  ref_acc;
    logic signed [DATA_WIDTH-1:0] ref_a, ref_b;
    longint signed                wide;
    int                           seed_v;

    localparam logic signed [DATA_WIDTH-1:0] MINV = {1'b1, {(DATA_WIDTH-1){1'b0}}};
    localparam logic signed [DATA_WIDTH-1:0] MAXV = {1'b0, {(DATA_WIDTH-1){1'b1}}};

    task automatic check(input string what);
        tests++;
        if (acc !== ref_acc || a_out !== ref_a || b_out !== ref_b) begin
            errors++;
            $display("FAIL [%0s] DW=%0d AW=%0d rst_n=%b clr=%b en=%b a_in=%0d b_in=%0d: exp acc=%0d a=%0d b=%0d got acc=%0d a=%0d b=%0d",
                     what, DATA_WIDTH, ACC_WIDTH, rst_n, clr, en, a_in, b_in,
                     ref_acc, ref_a, ref_b, acc, a_out, b_out);
        end
    endtask

    task automatic cycle(input logic r_n, input logic c, input logic e,
                         input logic signed [DATA_WIDTH-1:0] av,
                         input logic signed [DATA_WIDTH-1:0] bv,
                         input string what);
        @(negedge clk);
        rst_n = r_n; clr = c; en = e; a_in = av; b_in = bv;
        @(posedge clk);
        if (!r_n || c) begin
            ref_acc = '0; ref_a = '0; ref_b = '0;
        end else if (e) begin
            wide    = longint'(av) * longint'(bv);
            ref_acc = ref_acc + ACC_WIDTH'(wide);
            ref_a   = av;
            ref_b   = bv;
        end
        #1;
        check(what);
    endtask

    initial begin
        done = 0; tests = 0; errors = 0;
        rst_n = 0; clr = 0; en = 0; a_in = '0; b_in = '0;
        ref_acc = '0; ref_a = '0; ref_b = '0;
        seed_v = SEED;

        cycle(1'b0, 1'b0, 1'b1, 5, 6, "reset");
        // Same-pair forwarding and accumulation: 3 * -4 = -12.
        cycle(1'b1, 1'b1, 1'b0, 0, 0, "clear");
        cycle(1'b1, 1'b0, 1'b1, 3, -4, "3,-4");
        // Operands change every enabled cycle (exposes extra pipeline stages).
        cycle(1'b1, 1'b0, 1'b1, 7, 2, "7,2");
        cycle(1'b1, 1'b0, 1'b1, -5, 9, "-5,9");
        cycle(1'b1, 1'b0, 1'b1, 1, 1, "1,1");
        // Hold when disabled, operands changing.
        cycle(1'b1, 1'b0, 1'b0, 11, 12, "hold");
        cycle(1'b1, 1'b0, 1'b0, 13, 14, "hold2");
        // Extrema.
        cycle(1'b1, 1'b1, 1'b0, 0, 0, "clear");
        cycle(1'b1, 1'b0, 1'b1, MINV, MAXV, "min*max");
        cycle(1'b1, 1'b0, 1'b1, MINV, MINV, "min*min");
        cycle(1'b1, 1'b0, 1'b1, MAXV, MAXV, "max*max");
        cycle(1'b1, 1'b0, 1'b1, MAXV, MINV, "max*min");
        // clr overrides en, clearing forwarding too.
        cycle(1'b1, 1'b1, 1'b1, 4, 4, "clr over en");
        cycle(1'b1, 1'b0, 1'b1, 2, 3, "after clr");
        // Reset overrides everything.
        cycle(1'b0, 1'b1, 1'b1, 2, 3, "reset over all");
        cycle(1'b1, 1'b0, 1'b1, 1, 2, "after reset");

        for (int i = 0; i < 400; i++) begin
            logic signed [DATA_WIDTH-1:0] ra, rb;
            logic [3:0] ctl;
            ra  = DATA_WIDTH'($random(seed_v));
            rb  = DATA_WIDTH'($random(seed_v));
            ctl = 4'($random(seed_v));
            cycle((ctl != 4'd0), (ctl == 4'd1), (ctl > 4'd3), ra, rb, "random");
        end
        done = 1;
    end
endmodule

module pe_tb;
    logic clk = 0;
    always #5 clk = ~clk;

    logic done_a, done_b;
    int   tests_a, errors_a, tests_b, errors_b;

    pe_case #(.DATA_WIDTH(8), .ACC_WIDTH(32), .SEED(32'h0A0A)) u_default (
        .clk(clk), .done(done_a), .tests(tests_a), .errors(errors_a));
    pe_case #(.DATA_WIDTH(5), .ACC_WIDTH(12), .SEED(32'h0B0B)) u_narrow (
        .clk(clk), .done(done_b), .tests(tests_b), .errors(errors_b));

    initial begin
        $dumpfile("sim/pe_tb.vcd");
        $dumpvars(0, pe_tb);
    end

    initial begin
        repeat (20000) @(posedge clk);
        $display("FAIL watchdog timeout");
        $display("PE TEST RESULT: FAIL");
        $display("Tests: %0d", tests_a + tests_b);
        $display("Errors: %0d", errors_a + errors_b + 1);
        $finish;
    end

    initial begin
        int t, e;
        wait (done_a && done_b);
        @(posedge clk); #1;
        t = tests_a + tests_b;
        e = errors_a + errors_b;
        $display("========================================");
        if (e == 0 && t > 0) $display("PE TEST RESULT: PASS");
        else                 $display("PE TEST RESULT: FAIL");
        $display("Tests: %0d", t);
        $display("Errors: %0d", e);
        $display("========================================");
        $finish;
    end
endmodule
