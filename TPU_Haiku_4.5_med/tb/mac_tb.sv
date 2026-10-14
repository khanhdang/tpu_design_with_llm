module mac_tb();

    localparam CLK_PERIOD = 10;
    localparam WATCHDOG_MAX = 5000;

    // Primary MAC: DATA_WIDTH=8, ACC_WIDTH=32
    logic clk;
    logic rst_n;
    logic clr_p, en_p;
    logic signed [7:0] a_p, b_p;
    logic signed [31:0] acc_p;

    // Secondary MAC: DATA_WIDTH=8, ACC_WIDTH=16
    logic clr_s, en_s;
    logic signed [7:0] a_s, b_s;
    logic signed [15:0] acc_s;

    int tests = 0;
    int errors = 0;

    // Instantiate primary MAC
    mac #(.DATA_WIDTH(8), .ACC_WIDTH(32)) mac_primary (
        .clk(clk), .rst_n(rst_n), .clr(clr_p), .en(en_p),
        .a(a_p), .b(b_p), .acc(acc_p)
    );

    // Instantiate secondary MAC for 16-bit overflow testing
    mac #(.DATA_WIDTH(8), .ACC_WIDTH(16)) mac_secondary (
        .clk(clk), .rst_n(rst_n), .clr(clr_s), .en(en_s),
        .a(a_s), .b(b_s), .acc(acc_s)
    );

    // Clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Watchdog
    initial begin
        #(WATCHDOG_MAX * CLK_PERIOD);
        $display("FAIL: Timeout");
        errors = errors + 1;
        $finish;
    end

    task cycle;
        @(posedge clk);
        #1;
    endtask

    task check_32(string label, logic signed [31:0] actual, logic signed [31:0] expected);
        tests = tests + 1;
        if (actual !== expected) begin
            $display("FAIL %s: expected=%0d got=%0d", label, expected, actual);
            errors = errors + 1;
        end
    endtask

    task check_16(string label, logic signed [15:0] actual, logic signed [15:0] expected);
        tests = tests + 1;
        if (actual !== expected) begin
            $display("FAIL %s: expected=%0d got=%0d", label, expected, actual);
            errors = errors + 1;
        end
    endtask

    initial begin
        // Init
        rst_n = 0; clr_p = 0; en_p = 0; a_p = 0; b_p = 0;
        clr_s = 0; en_s = 0; a_s = 0; b_s = 0;

        cycle;
        cycle;
        @(negedge clk); rst_n = 1;
        cycle;

        // ========== PRIMARY MAC TESTS (32-bit) ==========

        // T1: Reset state
        check_32("T1_Reset", acc_p, 0);

        // T2: Simple multiplication (3 * 4 = 12)
        @(negedge clk); en_p = 1; a_p = 3; b_p = 4;
        cycle;
        check_32("T2_3x4", acc_p, 12);

        // T3: Accumulate negative (12 + (-3)*4 = 0)
        @(negedge clk); a_p = -3; b_p = 4;
        cycle;
        check_32("T3_Neg", acc_p, 0);

        // T4: Both negative (0 + (-3)*(-4) = 12)
        @(negedge clk); a_p = -3; b_p = -4;
        cycle;
        check_32("T4_BothNeg", acc_p, 12);

        // T5: Extreme: (-128) * 127 = -16256
        @(negedge clk); clr_p = 1;
        cycle;
        @(negedge clk); clr_p = 0; a_p = -128; b_p = 127;
        cycle;
        check_32("T5_Extreme1", acc_p, -16256);

        // T6: Extreme: (-128) * (-128) = 16384
        @(negedge clk); clr_p = 1;
        cycle;
        @(negedge clk); clr_p = 0; a_p = -128; b_p = -128;
        cycle;
        check_32("T6_Extreme2", acc_p, 16384);

        // T7: Zero product (a=0)
        @(negedge clk); a_p = 0; b_p = 5;
        cycle;
        check_32("T7_ZeroA", acc_p, 16384);

        // T8: Zero product (b=0)
        @(negedge clk); a_p = 5; b_p = 0;
        cycle;
        check_32("T8_ZeroB", acc_p, 16384);

        // T9: Repeated accumulation
        @(negedge clk); clr_p = 1;
        cycle;
        @(negedge clk); clr_p = 0; en_p = 1; a_p = 10; b_p = 10;
        cycle;
        check_32("T9_Acc1", acc_p, 100);

        @(negedge clk);
        cycle;
        check_32("T9_Acc2", acc_p, 200);

        @(negedge clk);
        cycle;
        check_32("T9_Acc3", acc_p, 300);

        // T10: Enable hold
        @(negedge clk); en_p = 0;
        cycle;
        check_32("T10_Hold", acc_p, 300);

        // T11: Clear overrides enable
        @(negedge clk); clr_p = 1; en_p = 1; a_p = 5; b_p = 6;
        cycle;
        check_32("T11_ClrOverEn", acc_p, 0);

        // T12: Accumulate after clear
        @(negedge clk); clr_p = 0; en_p = 1; a_p = 7; b_p = 8;
        cycle;
        check_32("T12_AftClear", acc_p, 56);

        // T13: Reset overrides all
        @(negedge clk); rst_n = 0; clr_p = 1; en_p = 1;
        cycle;
        check_32("T13_RstOvr", acc_p, 0);

        @(negedge clk); rst_n = 1; clr_p = 0; a_p = 2; b_p = 3;
        cycle;
        check_32("T13_AftRst", acc_p, 6);

        // T14-T23: Additional deterministic tests
        @(negedge clk); clr_p = 1; a_p = 0; b_p = 0;
        cycle;
        @(negedge clk); clr_p = 0; en_p = 1;
        cycle;

        // T14: 25 * 30 = 750
        @(negedge clk); a_p = 25; b_p = 30;
        cycle;
        check_32("T14_25x30", acc_p, 750);

        // T15: 750 + (-15)*20 = 750 - 300 = 450
        @(negedge clk); a_p = -15; b_p = 20;
        cycle;
        check_32("T15_Accum", acc_p, 450);

        // T16: 450 + (-50)*(-20) = 450 + 1000 = 1450
        @(negedge clk); a_p = -50; b_p = -20;
        cycle;
        check_32("T16_Accum", acc_p, 1450);

        // ========== SECONDARY MAC TESTS (16-bit with wraparound) ==========

        // T17: 16-bit initialization
        @(negedge clk); clr_s = 1;
        cycle;
        @(negedge clk); clr_s = 0; en_s = 1; a_s = -128; b_s = -128;
        cycle;
        // (-128) * (-128) = 16384
        check_16("T17_16bit1", acc_s, 16384);

        // T18: Accumulate again to trigger wrap
        @(negedge clk);
        cycle;
        // 16384 + 16384 = 32768, wraps to -32768 in 16-bit signed
        check_16("T18_16bit2", acc_s, -32768);

        // T19: Accumulate once more
        @(negedge clk);
        cycle;
        // -32768 + 16384 = -16384
        check_16("T19_16bit3", acc_s, -16384);

        // T20: Clear secondary
        @(negedge clk); clr_s = 1;
        cycle;
        check_16("T20_ClrSec", acc_s, 0);

        // T21: Quick secondary accumulation test
        @(negedge clk); clr_s = 0; en_s = 1; a_s = 1; b_s = 1;
        cycle;
        check_16("T21_SecSmall", acc_s, 1);

        // ========== FINAL SUMMARY ==========

        @(posedge clk);

        $display("========================================");
        if (errors === 0 && tests > 0) begin
            $display("MAC TEST RESULT: PASS");
        end else begin
            $display("MAC TEST RESULT: FAIL");
        end
        $display("Tests: %0d", tests);
        $display("Errors: %0d", errors);
        $display("========================================");

        $finish;
    end

endmodule
