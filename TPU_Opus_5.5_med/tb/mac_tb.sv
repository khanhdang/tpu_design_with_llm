// Self-checking testbench for mac.
// Two configurations (ACC_WIDTH=32 and ACC_WIDTH=16) run in parallel harnesses;
// the top aggregates their counters into a single MAC summary.

module mac_harness #(
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
    logic signed [DATA_WIDTH-1:0] a, b;
    logic signed [ACC_WIDTH-1:0]  acc;
    logic signed [ACC_WIDTH-1:0]  ref_acc;
    integer                       seed;

    mac #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en), .a(a), .b(b), .acc(acc)
    );

    task automatic report_mismatch(input string what, input logic signed [ACC_WIDTH-1:0] exp);
        errors = errors + 1;
        $display("FAIL MAC[DW=%0d,AW=%0d] %s @%0t: rst_n=%b clr=%b en=%b a=%0d b=%0d expected=%0d got=%0d (seed=%0d)",
                 DATA_WIDTH, ACC_WIDTH, what, $time, rst_n, clr, en, a, b, exp, acc, SEED);
    endtask

    // Compare the DUT against the reference accumulator.
    task automatic check(input string what);
        tests = tests + 1;
        if (acc !== ref_acc) report_mismatch(what, ref_acc);
    endtask

    // Compare the DUT against a hand-computed constant (wrapped to ACC_WIDTH).
    task automatic check_known(input string what, input longint value);
        logic signed [ACC_WIDTH-1:0] exp;
        exp   = value;
        tests = tests + 1;
        if (acc !== exp) report_mismatch(what, exp);
    endtask

    // One clock cycle: drive on the falling edge, model the rising edge,
    // then check after nonblocking updates settle.
    task automatic cycle(input logic r, input logic c, input logic e,
                         input logic signed [DATA_WIDTH-1:0] av,
                         input logic signed [DATA_WIDTH-1:0] bv,
                         input string what);
        longint prod;
        @(negedge clk);
        rst_n = r; clr = c; en = e; a = av; b = bv;
        @(posedge clk);
        prod = longint'(av) * longint'(bv);
        if (!r)      ref_acc = '0;
        else if (c)  ref_acc = '0;
        else if (e)  ref_acc = ref_acc + prod;   // truncates to ACC_WIDTH (wrap)
        #1 check(what);
    endtask

    task automatic clear_acc();
        cycle(1'b1, 1'b1, 1'b0, '0, '0, "clear");
    endtask

    integer i;
    logic r, c, e;
    logic signed [DATA_WIDTH-1:0] ra, rb;

    initial begin
        tests    = 0;
        errors   = 0;
        finished = 1'b0;
        seed     = SEED;
        rst_n = 1'b0; clr = 1'b0; en = 1'b0; a = '0; b = '0;
        ref_acc = '0;

        // Reset with all other controls active.
        cycle(1'b0, 1'b1, 1'b1, 8'sd5, 8'sd5, "reset");
        cycle(1'b0, 1'b0, 1'b1, 8'sd7, 8'sd9, "reset overrides en");

        // Zero products.
        cycle(1'b1, 1'b0, 1'b1, '0, 8'sd77, "0*77");
        cycle(1'b1, 1'b0, 1'b1, 8'sd77, '0, "77*0");
        if (DATA_WIDTH == 8) check_known("zero product const", 0);

        if (DATA_WIDTH == 8) begin
            clear_acc();
            cycle(1'b1, 1'b0, 1'b1, 8'sd3, 8'sd4, "3*4");
            check_known("3*4 const", 12);
            clear_acc();
            cycle(1'b1, 1'b0, 1'b1, -8'sd3, 8'sd4, "-3*4");
            check_known("-3*4 const", -12);
            clear_acc();
            cycle(1'b1, 1'b0, 1'b1, 8'sd3, -8'sd4, "3*-4");
            check_known("3*-4 const", -12);
            clear_acc();
            cycle(1'b1, 1'b0, 1'b1, -8'sd3, -8'sd4, "-3*-4");
            check_known("-3*-4 const", 12);
            clear_acc();
            cycle(1'b1, 1'b0, 1'b1, MINV, MAXV, "-128*127");
            check_known("-128*127 const", -16256);
            clear_acc();
            cycle(1'b1, 1'b0, 1'b1, MINV, MINV, "-128*-128");
            check_known("-128*-128 const", 16384);
            clear_acc();
            cycle(1'b1, 1'b0, 1'b1, MAXV, MAXV, "127*127");
            check_known("127*127 const", 16129);
        end

        // Repeated accumulation with changing operands.
        clear_acc();
        cycle(1'b1, 1'b0, 1'b1, 8'sd10, 8'sd10, "acc 10*10");
        cycle(1'b1, 1'b0, 1'b1, -8'sd5, 8'sd6, "acc -5*6");
        cycle(1'b1, 1'b0, 1'b1, 8'sd2, -8'sd9, "acc 2*-9");
        cycle(1'b1, 1'b0, 1'b1, -8'sd7, -8'sd7, "acc -7*-7");
        if (DATA_WIDTH == 8) check_known("acc sequence const", 100 - 30 - 18 + 49);

        // Enable low holds the value despite changing inputs.
        cycle(1'b1, 1'b0, 1'b0, 8'sd99, 8'sd99, "hold 1");
        cycle(1'b1, 1'b0, 1'b0, -8'sd99, 8'sd50, "hold 2");
        cycle(1'b1, 1'b0, 1'b0, MINV, MINV, "hold 3");
        if (DATA_WIDTH == 8) check_known("hold const", 101);

        // clr with en=0.
        cycle(1'b1, 1'b1, 1'b0, 8'sd11, 8'sd11, "clr en=0");
        // clr overrides en=1.
        cycle(1'b1, 1'b0, 1'b1, 8'sd20, 8'sd3, "acc before clr");
        cycle(1'b1, 1'b1, 1'b1, 8'sd20, 8'sd3, "clr overrides en");
        check_known("clr overrides en const", 0);
        // Reset overrides clr=0/en=1 after accumulation.
        cycle(1'b1, 1'b0, 1'b1, 8'sd20, 8'sd3, "acc before reset");
        cycle(1'b0, 1'b0, 1'b1, 8'sd20, 8'sd3, "reset overrides all");
        check_known("reset const", 0);

        // Wraparound: repeated (-128)*(-128) products.
        cycle(1'b1, 1'b1, 1'b0, '0, '0, "clear before wrap");
        for (i = 1; i <= 6; i = i + 1) begin
            cycle(1'b1, 1'b0, 1'b1, MINV, MINV, "wrap MIN*MIN");
            if (DATA_WIDTH == 8 && ACC_WIDTH == 16) begin
                case (i)
                    1: check_known("wrap16 16384", 16384);
                    2: check_known("wrap16 32768 -> -32768", -32768);
                    3: check_known("wrap16 -16384", -16384);
                    4: check_known("wrap16 0", 0);
                    5: check_known("wrap16 16384 again", 16384);
                    default: check_known("wrap16 -32768 again", -32768);
                endcase
            end
        end

        // Fixed-seed random operations.
        for (i = 0; i < RAND_OPS; i = i + 1) begin
            r  = ($random(seed) & 63) != 0;   // ~1.5% reset
            c  = ($random(seed) & 31) == 0;   // ~3% clear
            e  = ($random(seed) & 3)  != 0;   // ~75% enable
            ra = $random(seed);
            rb = $random(seed);
            if (i % 50 == 0) begin ra = MINV; end
            if (i % 50 == 1) begin rb = MAXV; end
            cycle(r, c, e, ra, rb, "random");
        end

        finished = 1'b1;
    end

endmodule

module mac_tb;

    localparam int MAX_CYCLES = 5000;

    logic   clk = 1'b0;
    always #5 clk = ~clk;

    integer t32, e32, t16, e16;
    logic   f32, f16;
    integer cycles = 0;
    logic   reported = 1'b0;

    mac_harness #(.DATA_WIDTH(8), .ACC_WIDTH(32), .RAND_OPS(400), .SEED(32'h1234)) h32 (
        .clk(clk), .tests(t32), .errors(e32), .finished(f32)
    );
    mac_harness #(.DATA_WIDTH(8), .ACC_WIDTH(16), .RAND_OPS(400), .SEED(32'h5678)) h16 (
        .clk(clk), .tests(t16), .errors(e16), .finished(f16)
    );

    initial begin
        $dumpfile("sim/mac_tb.vcd");
        $dumpvars(0, mac_tb);
    end

    task automatic summary(input integer tests, input integer errors);
        if (!reported) begin
            reported = 1'b1;
            $display("========================================");
            if (errors == 0 && tests > 0) $display("MAC TEST RESULT: PASS");
            else                          $display("MAC TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
            $display("========================================");
            $finish;
        end
    endtask

    // Cycle-based watchdog.
    always @(posedge clk) begin
        cycles <= cycles + 1;
        if (cycles >= MAX_CYCLES) begin
            $display("FAIL watchdog: timeout after %0d cycles", cycles);
            summary(t32 + t16, e32 + e16 + 1);
        end
    end

    initial begin
        wait (f32 === 1'b1 && f16 === 1'b1);
        #1;
        $display("MAC config DW=8 AW=32: checks=%0d mismatches=%0d", t32, e32);
        $display("MAC config DW=8 AW=16: checks=%0d mismatches=%0d", t16, e16);
        summary(t32 + t16, e32 + e16);
    end

endmodule
