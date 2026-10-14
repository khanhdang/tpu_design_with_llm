// Self-checking testbench for pe.
// Two PE instances receive the same stimulus: the default (DATA_WIDTH=8,
// ACC_WIDTH=32) and a non-default (DATA_WIDTH=4, ACC_WIDTH=16).
// Expected values come from a TB-side reference model that is updated from the
// driven inputs (never from DUT outputs) and wraps to ACC_WIDTH.
module pe_tb;
    localparam int DW8  = 8;
    localparam int AW8  = 32;
    localparam int DW4  = 4;
    localparam int AW4  = 16;

    logic clk   = 1'b0;
    logic rst_n = 1'b0;
    logic clr   = 1'b0;
    logic en    = 1'b0;
    logic signed [DW8-1:0] a8 = '0;
    logic signed [DW8-1:0] b8 = '0;
    logic signed [DW4-1:0] a4 = '0;
    logic signed [DW4-1:0] b4 = '0;

    logic signed [DW8-1:0] a8_out, b8_out;
    logic signed [AW8-1:0] acc8;
    logic signed [DW4-1:0] a4_out, b4_out;
    logic signed [AW4-1:0] acc4;

    pe #(.DATA_WIDTH(DW8), .ACC_WIDTH(AW8)) u_pe8 (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
        .a_in(a8), .b_in(b8), .a_out(a8_out), .b_out(b8_out), .acc(acc8)
    );
    pe #(.DATA_WIDTH(DW4), .ACC_WIDTH(AW4)) u_pe4 (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
        .a_in(a4), .b_in(b4), .a_out(a4_out), .b_out(b4_out), .acc(acc4)
    );

    always #5 clk = ~clk;

    // Reference state for the default instance.
    longint ref_af8  = 0;
    longint ref_bf8  = 0;
    longint ref_acc8 = 0;
    // Reference state for the non-default instance.
    longint ref_af4  = 0;
    longint ref_bf4  = 0;
    longint ref_acc4 = 0;

    integer tests  = 0;
    integer errors = 0;
    integer seed   = 12345;
    bit     done   = 1'b0;

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

    task automatic print_summary;
        begin
            if (errors == 0 && tests > 0)
                $display("PE TEST RESULT: PASS");
            else
                $display("PE TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
        end
    endtask

    // Compare every DUT output against the reference model.
    task automatic check_model(input string tag);
        begin
            tests++;
            if (a8_out !== ref_af8[DW8-1:0] || b8_out !== ref_bf8[DW8-1:0]
                    || acc8 !== ref_acc8[AW8-1:0]) begin
                errors++;
                $display("FAIL PE8 %s: expected a_out=%0d b_out=%0d acc=%0d got a_out=%0d b_out=%0d acc=%0d",
                         tag, $signed(ref_af8[DW8-1:0]), $signed(ref_bf8[DW8-1:0]),
                         $signed(ref_acc8[AW8-1:0]), a8_out, b8_out, acc8);
                $display("     inputs: rst_n=%0b clr=%0b en=%0b a_in=%0d b_in=%0d",
                         rst_n, clr, en, a8, b8);
            end
            tests++;
            if (a4_out !== ref_af4[DW4-1:0] || b4_out !== ref_bf4[DW4-1:0]
                    || acc4 !== ref_acc4[AW4-1:0]) begin
                errors++;
                $display("FAIL PE4 %s: expected a_out=%0d b_out=%0d acc=%0d got a_out=%0d b_out=%0d acc=%0d",
                         tag, $signed(ref_af4[DW4-1:0]), $signed(ref_bf4[DW4-1:0]),
                         $signed(ref_acc4[AW4-1:0]), a4_out, b4_out, acc4);
                $display("     inputs: rst_n=%0b clr=%0b en=%0b a_in=%0d b_in=%0d",
                         rst_n, clr, en, a4, b4);
            end
        end
    endtask

    // Check literal values for both instances; used where the expected value
    // is hand-derived and fits in both data widths.
    task automatic expect_known(input longint af, input longint bf, input longint acc,
                                input string tag);
        begin
            tests++;
            if (a8_out !== af[DW8-1:0] || b8_out !== bf[DW8-1:0] || acc8 !== acc[AW8-1:0]) begin
                errors++;
                $display("FAIL PE8 known %s: expected a_out=%0d b_out=%0d acc=%0d got a_out=%0d b_out=%0d acc=%0d",
                         tag, af, bf, acc, a8_out, b8_out, acc8);
            end
            tests++;
            if (a4_out !== af[DW4-1:0] || b4_out !== bf[DW4-1:0] || acc4 !== acc[AW4-1:0]) begin
                errors++;
                $display("FAIL PE4 known %s: expected a_out=%0d b_out=%0d acc=%0d got a_out=%0d b_out=%0d acc=%0d",
                         tag, af, bf, acc, a4_out, b4_out, acc4);
            end
        end
    endtask

    // One clock cycle: drive inputs at negedge, update the reference at posedge,
    // and check after the nonblocking updates have settled.
    task automatic cycle(input bit rstn_i, input bit clr_i, input bit en_i,
                         input logic signed [DW8-1:0] a_i, input logic signed [DW8-1:0] b_i,
                         input string tag);
        longint prod8;
        longint prod4;
        begin
            @(negedge clk);
            rst_n = rstn_i;
            clr   = clr_i;
            en    = en_i;
            a8    = a_i;
            b8    = b_i;
            a4    = a_i[DW4-1:0];
            b4    = b_i[DW4-1:0];

            @(posedge clk);
            prod8 = longint'(a8) * longint'(b8);
            prod4 = longint'(a4) * longint'(b4);
            if (!rstn_i || clr_i) begin
                ref_af8  = 0;
                ref_bf8  = 0;
                ref_acc8 = 0;
                ref_af4  = 0;
                ref_bf4  = 0;
                ref_acc4 = 0;
            end else if (en_i) begin
                ref_af8  = longint'(a8);
                ref_bf8  = longint'(b8);
                ref_acc8 = wrap(ref_acc8 + prod8, AW8);
                ref_af4  = longint'(a4);
                ref_bf4  = longint'(b4);
                ref_acc4 = wrap(ref_acc4 + prod4, AW4);
            end

            #1;
            check_model(tag);
        end
    endtask

    // Watchdog: bounded run time, reports FAIL if the main sequence hangs.
    initial begin
        #2000000;
        if (!done) begin
            errors++;
            $display("FAIL PE watchdog timeout");
            done = 1'b1;
            print_summary();
            $finish;
        end
    end

    initial begin
        integer i;
        integer r;
        logic rstn_r;
        logic clr_r;
        logic en_r;
        logic signed [DW8-1:0] a_r;
        logic signed [DW8-1:0] b_r;

        $dumpfile("sim/pe_tb.vcd");
        $dumpvars(0, pe_tb);

        // Reset, two cycles.
        cycle(0, 0, 0, 0, 0, "reset");
        cycle(0, 0, 0, 0, 0, "reset2");
        expect_known(0, 0, 0, "after reset");

        // Spec example: a_in=3, b_in=-4 on one enabled edge after clear.
        cycle(1, 1, 0, 0, 0, "clear");
        cycle(1, 0, 1, 3, -4, "3,-4 enabled");
        expect_known(3, -4, -12, "3,-4 enabled");

        // Operands change every enabled cycle; forwarding must follow the
        // same sampled pair, with no extra pipeline stage.
        cycle(1, 1, 0, 0, 0, "clear");
        cycle(1, 0, 1, 1, 2, "pair 1");
        expect_known(1, 2, 2, "pair 1");
        cycle(1, 0, 1, 5, -6, "pair 2");
        expect_known(5, -6, -28, "pair 2");
        cycle(1, 0, 1, -7, 3, "pair 3");
        expect_known(-7, 3, -49, "pair 3");
        cycle(1, 0, 1, 2, 2, "pair 4");
        expect_known(2, 2, -45, "pair 4");

        // Enable low holds forwarding registers and accumulator.
        for (i = 0; i < 3; i++)
            cycle(1, 0, 0, 7, -7, "hold");
        expect_known(2, 2, -45, "hold");

        // clr with en=0 clears everything.
        cycle(1, 1, 0, 7, 7, "clr en=0");
        expect_known(0, 0, 0, "clr en=0");

        // clr overrides en=1.
        cycle(1, 0, 1, 2, 2, "accumulate 4");
        expect_known(2, 2, 4, "accumulate 4");
        cycle(1, 1, 1, 5, 5, "clr overrides en");
        expect_known(0, 0, 0, "clr overrides en");

        // Reset overrides en=1 and clr=0.
        cycle(1, 1, 0, 0, 0, "clear");
        cycle(1, 0, 1, 3, 3, "3*3");
        expect_known(3, 3, 9, "3*3");
        cycle(0, 0, 1, 5, 5, "reset overrides en");
        expect_known(0, 0, 0, "reset overrides en");

        // Sign extrema (the 4-bit instance sees the low nibble of each value).
        cycle(1, 1, 0, 0, 0, "clear");
        cycle(1, 0, 1, -128, -128, "extrema (-128)(-128)");
        cycle(1, 0, 1, 127, 127, "extrema 127*127");
        cycle(1, 0, 1, -128, 127, "extrema (-128)(127)");
        cycle(1, 0, 1, 127, -128, "extrema 127*(-128)");

        // Accumulate several products with mixed signs.
        cycle(1, 1, 0, 0, 0, "clear");
        for (i = 0; i < 6; i++)
            cycle(1, 0, 1, 10 - 3 * i, 2 * i - 5, "mixed signs");

        // Fixed-seed random cycles: random resets, clears, enables and operands.
        for (i = 0; i < 2000; i++) begin
            r = $unsigned($random(seed)) % 200;
            rstn_r = (r != 0);
            r = $unsigned($random(seed)) % 16;
            clr_r = (r == 0);
            r = $unsigned($random(seed)) % 4;
            en_r = (r != 0);
            a_r = $random(seed);
            b_r = $random(seed);
            cycle(rstn_r, clr_r, en_r, a_r, b_r, "random");
        end

        done = 1'b1;
        print_summary();
        $finish;
    end
endmodule
