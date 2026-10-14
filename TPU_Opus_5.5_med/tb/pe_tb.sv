// Self-checking testbench for pe.
// Default (DATA_WIDTH=8, ACC_WIDTH=32) and non-default (DATA_WIDTH=4, ACC_WIDTH=12)
// harnesses run in parallel; the top aggregates into one PE summary.

module pe_harness #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int RAND_OPS   = 300,
    parameter int SEED       = 1
) (
    input  logic   clk,
    output integer tests,
    output integer errors,
    output logic   finished
);

    localparam logic signed [DATA_WIDTH-1:0] MAXV = {1'b0, {(DATA_WIDTH-1){1'b1}}};
    localparam logic signed [DATA_WIDTH-1:0] MINV = {1'b1, {(DATA_WIDTH-1){1'b0}}};

    logic                         rst_n, clr, en;
    logic signed [DATA_WIDTH-1:0] a_in, b_in, a_out, b_out;
    logic signed [ACC_WIDTH-1:0]  acc;

    // Reference state, updated only from TB-driven inputs.
    logic signed [ACC_WIDTH-1:0]  ref_acc;
    logic signed [DATA_WIDTH-1:0] ref_a, ref_b;
    integer                       seed;

    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
        .a_in(a_in), .b_in(b_in), .a_out(a_out), .b_out(b_out), .acc(acc)
    );

    task automatic check(input string what);
        tests = tests + 3;
        if (a_out !== ref_a || b_out !== ref_b || acc !== ref_acc) begin
            if (a_out !== ref_a)   errors = errors + 1;
            if (b_out !== ref_b)   errors = errors + 1;
            if (acc   !== ref_acc) errors = errors + 1;
            $display("FAIL PE[DW=%0d,AW=%0d] %s @%0t: rst_n=%b clr=%b en=%b a_in=%0d b_in=%0d | expected a_out=%0d b_out=%0d acc=%0d | got a_out=%0d b_out=%0d acc=%0d (seed=%0d)",
                     DATA_WIDTH, ACC_WIDTH, what, $time, rst_n, clr, en, a_in, b_in,
                     ref_a, ref_b, ref_acc, a_out, b_out, acc, SEED);
        end
    endtask

    task automatic check_known(input string what, input longint ea, input longint eb, input longint eacc);
        logic signed [DATA_WIDTH-1:0] xa, xb;
        logic signed [ACC_WIDTH-1:0]  xacc;
        xa = ea; xb = eb; xacc = eacc;
        tests = tests + 1;
        if (a_out !== xa || b_out !== xb || acc !== xacc) begin
            errors = errors + 1;
            $display("FAIL PE[DW=%0d,AW=%0d] %s: expected a_out=%0d b_out=%0d acc=%0d got a_out=%0d b_out=%0d acc=%0d",
                     DATA_WIDTH, ACC_WIDTH, what, xa, xb, xacc, a_out, b_out, acc);
        end
    endtask

    task automatic cycle(input logic r, input logic c, input logic e,
                         input logic signed [DATA_WIDTH-1:0] av,
                         input logic signed [DATA_WIDTH-1:0] bv,
                         input string what);
        longint prod;
        @(negedge clk);
        rst_n = r; clr = c; en = e; a_in = av; b_in = bv;
        @(posedge clk);
        prod = longint'(av) * longint'(bv);
        if (!r || c) begin
            ref_acc = '0; ref_a = '0; ref_b = '0;
        end else if (e) begin
            ref_acc = ref_acc + prod;
            ref_a   = av;
            ref_b   = bv;
        end
        #1 check(what);
    endtask

    integer i;
    logic r, c, e;
    logic signed [DATA_WIDTH-1:0] ra, rb;

    initial begin
        tests    = 0;
        errors   = 0;
        finished = 1'b0;
        seed     = SEED;
        rst_n = 1'b0; clr = 1'b0; en = 1'b0; a_in = '0; b_in = '0;
        ref_acc = '0; ref_a = '0; ref_b = '0;

        cycle(1'b0, 1'b0, 1'b1, 3, 3, "reset");
        cycle(1'b0, 1'b1, 1'b1, 2, 2, "reset with clr/en");

        // Forwarding and accumulation from the same sampled pair.
        cycle(1'b1, 1'b0, 1'b1, 3, -4, "a=3 b=-4");
        check_known("same pair 3,-4", 3, -4, -12);

        // Change operands every enabled cycle to expose extra pipeline stages.
        cycle(1'b1, 1'b0, 1'b1, 5, 2, "seq 5,2");
        check_known("seq 5,2", 5, 2, -12 + 10);
        cycle(1'b1, 1'b0, 1'b1, -1, 6, "seq -1,6");
        check_known("seq -1,6", -1, 6, -2 - 6);
        cycle(1'b1, 1'b0, 1'b1, 7, -7, "seq 7,-7");
        check_known("seq 7,-7", 7, -7, -8 - 49);

        // Sign extrema.
        cycle(1'b1, 1'b1, 1'b0, 0, 0, "clear");
        cycle(1'b1, 1'b0, 1'b1, MINV, MAXV, "MIN*MAX");
        check_known("MIN*MAX", MINV, MAXV, longint'(MINV) * longint'(MAXV));
        cycle(1'b1, 1'b0, 1'b1, MINV, MINV, "MIN*MIN");
        cycle(1'b1, 1'b0, 1'b1, MAXV, MINV, "MAX*MIN");
        cycle(1'b1, 1'b0, 1'b1, MAXV, MAXV, "MAX*MAX");

        // Hold: outputs and accumulator frozen while en=0.
        cycle(1'b1, 1'b0, 1'b0, 1, 1, "hold 1");
        cycle(1'b1, 1'b0, 1'b0, -2, 5, "hold 2");
        check_known("hold keeps MAX,MAX", MAXV, MAXV,
                    longint'(MINV) * longint'(MAXV) + longint'(MINV) * longint'(MINV)
                    + longint'(MAXV) * longint'(MINV) + longint'(MAXV) * longint'(MAXV));

        // clr overrides en; clr with en=0.
        cycle(1'b1, 1'b0, 1'b1, 4, 4, "acc before clr");
        cycle(1'b1, 1'b1, 1'b1, 6, 6, "clr overrides en");
        check_known("clr zeros all", 0, 0, 0);
        cycle(1'b1, 1'b0, 1'b1, 4, 4, "acc before clr en=0");
        cycle(1'b1, 1'b1, 1'b0, 6, 6, "clr en=0");
        check_known("clr en=0 zeros all", 0, 0, 0);

        // Reset overrides everything.
        cycle(1'b1, 1'b0, 1'b1, 2, 3, "acc before reset");
        cycle(1'b0, 1'b0, 1'b1, 2, 3, "reset overrides");
        check_known("reset zeros all", 0, 0, 0);

        // Fixed-seed random cycles.
        for (i = 0; i < RAND_OPS; i = i + 1) begin
            r  = ($random(seed) & 63) != 0;
            c  = ($random(seed) & 31) == 0;
            e  = ($random(seed) & 3)  != 0;
            ra = $random(seed);
            rb = $random(seed);
            cycle(r, c, e, ra, rb, "random");
        end

        finished = 1'b1;
    end

endmodule

module pe_tb;

    localparam int MAX_CYCLES = 5000;

    logic   clk = 1'b0;
    always #5 clk = ~clk;

    integer t0, e0, t1, e1;
    logic   f0, f1;
    integer cycles = 0;
    logic   reported = 1'b0;

    pe_harness #(.DATA_WIDTH(8), .ACC_WIDTH(32), .RAND_OPS(400), .SEED(32'h2468)) h_default (
        .clk(clk), .tests(t0), .errors(e0), .finished(f0)
    );
    pe_harness #(.DATA_WIDTH(4), .ACC_WIDTH(12), .RAND_OPS(400), .SEED(32'h1357)) h_narrow (
        .clk(clk), .tests(t1), .errors(e1), .finished(f1)
    );

    initial begin
        $dumpfile("sim/pe_tb.vcd");
        $dumpvars(0, pe_tb);
    end

    task automatic summary(input integer tests, input integer errors);
        if (!reported) begin
            reported = 1'b1;
            $display("========================================");
            if (errors == 0 && tests > 0) $display("PE TEST RESULT: PASS");
            else                          $display("PE TEST RESULT: FAIL");
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
            summary(t0 + t1, e0 + e1 + 1);
        end
    end

    initial begin
        wait (f0 === 1'b1 && f1 === 1'b1);
        #1;
        $display("PE config DW=8 AW=32: checks=%0d mismatches=%0d", t0, e0);
        $display("PE config DW=4 AW=12: checks=%0d mismatches=%0d", t1, e1);
        summary(t0 + t1, e0 + e1);
    end

endmodule
