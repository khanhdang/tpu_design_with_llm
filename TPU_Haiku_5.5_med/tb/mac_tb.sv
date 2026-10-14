// Self-checking testbench for mac.
// Two MAC instances (ACC_WIDTH=32 and ACC_WIDTH=16) receive the same stimulus.
// Expected values come from a 64-bit reference model that wraps to ACC_WIDTH.
module mac_tb;
    localparam int DW   = 8;
    localparam int AW32 = 32;
    localparam int AW16 = 16;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic clr = 1'b0;
    logic en = 1'b0;
    logic signed [DW-1:0] a = '0;
    logic signed [DW-1:0] b = '0;
    logic signed [AW32-1:0] acc32;
    logic signed [AW16-1:0] acc16;

    mac #(.DATA_WIDTH(DW), .ACC_WIDTH(AW32)) u_mac32 (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en), .a(a), .b(b), .acc(acc32)
    );
    mac #(.DATA_WIDTH(DW), .ACC_WIDTH(AW16)) u_mac16 (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en), .a(a), .b(b), .acc(acc16)
    );

    always #5 clk = ~clk;

    longint ref32 = 0;
    longint ref16 = 0;
    integer tests  = 0;
    integer errors = 0;
    bit     done   = 1'b0;
    integer seed   = 12345;

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
                $display("MAC TEST RESULT: PASS");
            else
                $display("MAC TEST RESULT: FAIL");
            $display("Tests: %0d", tests);
            $display("Errors: %0d", errors);
        end
    endtask

    // Compare both DUTs against the reference model.
    task automatic check_model(input string tag);
        logic [AW32-1:0] exp32;
        logic [AW16-1:0] exp16;
        begin
            exp32 = ref32[AW32-1:0];
            exp16 = ref16[AW16-1:0];
            tests++;
            if (acc32 !== exp32) begin
                errors++;
                $display("FAIL MAC32 %s: expected=%0d got=%0d (a=%0d b=%0d clr=%0b en=%0b rst_n=%0b)",
                         tag, $signed(exp32), acc32, a, b, clr, en, rst_n);
            end
            tests++;
            if (acc16 !== exp16) begin
                errors++;
                $display("FAIL MAC16 %s: expected=%0d got=%0d (a=%0d b=%0d clr=%0b en=%0b rst_n=%0b)",
                         tag, $signed(exp16), acc16, a, b, clr, en, rst_n);
            end
        end
    endtask

    // Check a known literal value against both DUTs.
    task automatic expect_known(input longint v32, input longint v16, input string tag);
        begin
            tests++;
            if (acc32 !== v32[AW32-1:0]) begin
                errors++;
                $display("FAIL MAC32 known %s: expected=%0d got=%0d", tag, v32, acc32);
            end
            tests++;
            if (acc16 !== v16[AW16-1:0]) begin
                errors++;
                $display("FAIL MAC16 known %s: expected=%0d got=%0d", tag, v16, acc16);
            end
        end
    endtask

    // One clock cycle: drive inputs at negedge, update the model at posedge,
    // and check after the nonblocking updates have settled.
    task automatic cycle(input bit rstn_i, input bit clr_i, input bit en_i,
                         input logic signed [DW-1:0] a_i, input logic signed [DW-1:0] b_i,
                         input string tag);
        longint prod;
        begin
            @(negedge clk);
            rst_n = rstn_i;
            clr   = clr_i;
            en    = en_i;
            a     = a_i;
            b     = b_i;

            @(posedge clk);
            prod = longint'(a_i) * longint'(b_i);
            if (!rstn_i) begin
                ref32 = 0;
                ref16 = 0;
            end else if (clr_i) begin
                ref32 = 0;
                ref16 = 0;
            end else if (en_i) begin
                ref32 = wrap(ref32 + prod, AW32);
                ref16 = wrap(ref16 + prod, AW16);
            end

            #1;
            check_model(tag);
        end
    endtask

    // Watchdog: bounded run time, reports FAIL if the main sequence hangs.
    initial begin
        #1000000;
        if (!done) begin
            errors++;
            $display("FAIL MAC watchdog timeout");
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
        logic signed [DW-1:0] a_r;
        logic signed [DW-1:0] b_r;

        $dumpfile("sim/mac_tb.vcd");
        $dumpvars(0, mac_tb);

        // Reset, two cycles.
        cycle(0, 0, 0, 0, 0, "reset");
        cycle(0, 0, 0, 0, 0, "reset2");
        expect_known(0, 0, "after reset");

        // Zero product.
        cycle(1, 1, 0, 0, 0, "clear before zero");
        cycle(1, 0, 1, 0, 5, "zero product");
        expect_known(0, 0, "zero product");

        // Known products: 3*4=12, (-3)*4=-12.
        cycle(1, 1, 0, 0, 0, "clear");
        cycle(1, 0, 1, 3, 4, "3*4");
        expect_known(12, 12, "3*4");
        cycle(1, 1, 0, 0, 0, "clear");
        cycle(1, 0, 1, -3, 4, "(-3)*4");
        expect_known(-12, -12, "(-3)*4");

        // Extrema: (-128)*127=-16256, (-128)*(-128)=16384, 127*127=16129.
        cycle(1, 1, 0, 0, 0, "clear");
        cycle(1, 0, 1, -128, 127, "(-128)*127");
        expect_known(-16256, -16256, "(-128)*127");
        cycle(1, 1, 0, 0, 0, "clear");
        cycle(1, 0, 1, -128, -128, "(-128)*(-128)");
        expect_known(16384, 16384, "(-128)*(-128)");
        cycle(1, 1, 0, 0, 0, "clear");
        cycle(1, 0, 1, 127, 127, "127*127");
        expect_known(16129, 16129, "127*127");

        // Repeated accumulation: five products of 1*1.
        cycle(1, 1, 0, 0, 0, "clear");
        for (i = 0; i < 5; i++)
            cycle(1, 0, 1, 1, 1, "accumulate 1*1");
        expect_known(5, 5, "five 1*1");

        // Enable low holds the accumulator.
        for (i = 0; i < 3; i++)
            cycle(1, 0, 0, 7, 7, "hold");
        expect_known(5, 5, "hold");

        // clr with en=0 clears.
        cycle(1, 1, 0, 7, 7, "clr en=0");
        expect_known(0, 0, "clr en=0");

        // clr overrides en=1.
        cycle(1, 0, 1, 2, 2, "accumulate 4");
        cycle(1, 1, 1, 5, 5, "clr overrides en");
        expect_known(0, 0, "clr overrides en");

        // Reset overrides en=1 and clr=0.
        cycle(1, 1, 0, 0, 0, "clear");
        cycle(1, 0, 1, 3, 3, "3*3");
        expect_known(9, 9, "3*3");
        cycle(0, 0, 1, 5, 5, "reset overrides en");
        expect_known(0, 0, "reset overrides en");

        // Wraparound: two 16384 products give 32768, which is -32768 in 16 bits.
        cycle(1, 1, 0, 0, 0, "clear");
        cycle(1, 0, 1, -128, -128, "wrap 1");
        cycle(1, 0, 1, -128, -128, "wrap 2");
        expect_known(32768, -32768, "wrap 32768");
        cycle(1, 0, 1, -128, -128, "wrap 3");
        expect_known(49152, -16384, "wrap 49152");

        // Fixed-seed random operations, checked by the reference model.
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
